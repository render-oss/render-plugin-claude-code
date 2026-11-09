# Task Patterns

These examples use the Render SDK 1.x task model. Every task accepts `TaskContext` first, and chained runs go through `ctx.run`.

For Python snippets, assume:

```python
from render import Retry, TaskContext, Workflows

app = Workflows()
```

For TypeScript snippets, assume:

```typescript
import { task, type TaskContext } from "@renderinc/sdk/workflows";
```

## Fan-Out and Fan-In

Use concurrent chaining when independent work benefits from separate compute and retry boundaries.

Python:

```python
import asyncio

@app.task
def process_image(_ctx: TaskContext, url: str) -> dict:
    return {"url": url, "success": True}

@app.task
async def process_batch(ctx: TaskContext, image_urls: list[str]) -> dict:
    results = await asyncio.gather(
        *(ctx.run(process_image, url) for url in image_urls)
    )
    successful = sum(1 for result in results if result["success"])
    return {
        "total": len(image_urls),
        "processed": successful,
        "failed": len(image_urls) - successful,
        "results": list(results),
    }
```

TypeScript:

```typescript
const processImage = task(
  { name: "processImage" },
  function processImage(_ctx: TaskContext, url: string) {
    return { url, success: true };
  },
);

task(
  { name: "processBatch" },
  async function processBatch(ctx: TaskContext, imageUrls: string[]) {
    const results = await Promise.all(
      imageUrls.map((url) => ctx.run(processImage, url)),
    );
    const successful = results.filter((result) => result.success).length;
    return {
      total: imageUrls.length,
      processed: successful,
      failed: imageUrls.length - successful,
      results,
    };
  },
);
```

Avoid unbounded fan-out when the input can be arbitrarily large. Batch inputs or add application-level concurrency control when downstream systems, rate limits, or cost require it.

## Sequential Pipeline

Use sequential chaining when each stage depends on the prior stage's result.

Python:

```python
@app.task
def extract(_ctx: TaskContext, source: str) -> dict:
    return {"source": source, "records": []}

@app.task
def transform(_ctx: TaskContext, data: dict) -> dict:
    return {"records": data["records"]}

@app.task
def load(_ctx: TaskContext, destination: str, data: dict) -> dict:
    return {"destination": destination, "loaded": len(data["records"])}

@app.task
async def etl_pipeline(
    ctx: TaskContext,
    source: str,
    destination: str,
) -> dict:
    raw_data = await ctx.run(extract, source)
    transformed = await ctx.run(transform, raw_data)
    return await ctx.run(load, destination, transformed)
```

TypeScript:

```typescript
const extract = task(
  { name: "extract" },
  (_ctx: TaskContext, source: string) => ({ source, records: [] as object[] }),
);

const transform = task(
  { name: "transform" },
  (_ctx: TaskContext, data: { records: object[] }) => ({ records: data.records }),
);

const load = task(
  { name: "load" },
  (_ctx: TaskContext, destination: string, data: { records: object[] }) => ({
    destination,
    loaded: data.records.length,
  }),
);

task(
  { name: "etlPipeline" },
  async function etlPipeline(
    ctx: TaskContext,
    source: string,
    destination: string,
  ) {
    const rawData = await ctx.run(extract, source);
    const transformed = await ctx.run(transform, rawData);
    return ctx.run(load, destination, transformed);
  },
);
```

## Retrying a Task-Start Request

A caller can lose the reply after Render accepts a task. Repeating an unkeyed start can then create another run. A saved request identifier, called an **idempotency key**, lets Render recognize the repeated submission.

Use Python `render>=1.2.0` or TypeScript `@renderinc/sdk>=1.2.0` for the options below. Check the installed package before generating code. The [task-start API contract](https://api-docs.render.com/reference/createtask) defines these boundaries:

- Keys contain 1 to 255 characters. The same key returns the original run for 24 hours within the same Workflow version. Repeated input is ignored.
- Save the key, exact input, task slug with its original version, and creation time **before** the first request. Use the application's durable request or event record, scoped to the caller and operation. Bind the key to that input and reject conflicting reuse. Do not use one global key, an input hash alone, or a new random key on every retry.
- Preserve the original version using `{workflow-slug}/{task-name}:{version}`. Switching to the latest version can create a second run with the same key. Stop recovery if the original version cannot be addressed, or before the 24-hour window ends, and reconcile the saved operation instead of silently creating a new key.
- Save the returned task run ID and use it for polling. A timeout or aborted start means acceptance is unknown; it does not prove the task failed. Keep the saved submission available across the caller's retries and restarts.
- A deliberate new request, a new scheduled occurrence, or a new attempt after a confirmed terminal failure needs a new identity. Reusing the failed run's key returns that failed run, not a fresh attempt.

These helpers show only the SDK call. Their caller must load and validate the saved record described above, including its age, input binding, and version. They do not generate or persist identities for the application.

Python async client:

```python
# The client reads RENDER_API_KEY in the process submitting work.
from render import RenderAsync

client = RenderAsync()

async def start_saved_submission(
    task_slug: str, input_data: list, submission_key: str
) -> str:
    # These values come from the saved request, including its versioned task slug.
    # A retry passes the same values after checking that recovery is still allowed.
    started = await client.workflows.start_task(
        task_slug, input_data, idempotency_key=submission_key
    )
    # Save this ID with the request so later checks poll instead of starting again.
    return started.id
```

TypeScript client:

```typescript
// The client reads RENDER_API_KEY in the process submitting work.
import { Render } from "@renderinc/sdk";

const client = new Render();

async function startSavedSubmission(
  taskSlug: string, inputData: unknown[], submissionKey: string,
  signal?: AbortSignal,
): Promise<string> {
  // The caller has checked the saved input, original version, and recovery age.
  // Pass cancellation and the saved key together in the third argument.
  const started = await client.workflows.startTask(taskSlug, inputData, {
    idempotencyKey: submissionKey,
    signal,
  });
  // Save this ID before responding to the browser or acknowledging the event.
  return started.taskRunId;
}
```

Python sync `start_task` uses the same keyword without `await`. `run_task` and `runTask` also accept their language's key option. Putting `idempotencyKey` inside task input does not enable submission deduplication, and passing it to `ctx.run` would change task arguments rather than configure a client start.

Verify the real caller path: simulate acceptance followed by a lost reply, recover after reloading its saved record, and assert one root run with the same key, input, and version. Also check two deliberate identical-input requests remain distinct, conflicting input and expired recovery are refused, and the real SDK emits `idempotencyKey` in the API body. A mock that merely accepts an extra argument does not prove that field reaches Render.

## Task Execution Retries and Side Effects

Tasks retry automatically by default. A start key only deduplicates creation of the root run within the boundary above. It does not make repeated task attempts, model calls, emails, payments, or restarted parent tasks execute exactly once. Preserve application records and provider-level keys or another duplicate-effect guard where needed. `ctx.run` chaining is a separate API; do not infer caller-controlled child-run recovery from the root start option.

Python:

```python
@app.task(
    retry=Retry(
        max_retries=5,
        wait_duration_ms=2000,
        backoff_scaling=2.0,
    )
)
def fetch_document(_ctx: TaskContext, url: str) -> str:
    import urllib.request

    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode()
```

TypeScript:

```typescript
task(
  {
    name: "fetchDocument",
    retry: {
      maxRetries: 5,
      waitDurationMs: 2000,
      backoffScaling: 2,
    },
  },
  async function fetchDocument(_ctx: TaskContext, url: string): Promise<string> {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.text();
  },
);
```

Do not retry every error indiscriminately in task code. Let the configured task policy handle run retries, and distinguish permanent validation failures from transient upstream failures when the task itself implements request-level retry logic. For common execution issues and fixes, see [troubleshooting.md](troubleshooting.md).

## Testing Task Logic In Process

SDK 1.x returns task definitions rather than callable task wrappers. Invoke `.func` with a test context for unit tests:

Python:

```python
class NoSubtasks:
    async def run(self, task, *args, **kwargs):
        raise AssertionError("unexpected chained run")

assert process_image.func(NoSubtasks(), "https://example.com/a.png")["success"]
```

TypeScript:

```typescript
const noSubtasks = {
  metadata: {},
  run: async () => {
    throw new Error("unexpected chained run");
  },
};

const result = processImage.func(noSubtasks, "https://example.com/a.png");
```

For orchestration tests, supply a fake `TaskContext.run` that records task definitions and returns controlled results.

## Scheduled Trigger

Render Workflows does not currently provide native scheduling. A Render cron job can trigger a deployed task with the SDK client.

Python sync client:

```python
from render import Render

def main() -> None:
    render = Render()
    result = render.workflows.run_task("my-workflow/daily-cleanup", [])
    print(result.status)

if __name__ == "__main__":
    main()
```

TypeScript:

```typescript
import { Render } from "@renderinc/sdk";

const render = new Render();
const result = await render.workflows.runTask("my-workflow/daily-cleanup", []);
console.log(result.status);
```

Store `RENDER_API_KEY` as a secret on the triggering service.

## Cross-Workflow Call

`ctx.run` only chains tasks in the same workflow service. To call a different workflow, use the API client. This creates an independent run rather than a parent-child relationship in the workflow graph.

Python:

```python
from render import RenderAsync

@app.task
async def orchestrate(_ctx: TaskContext, data: dict) -> object:
    render = RenderAsync()
    result = await render.workflows.run_task(
        "other-workflow/process",
        [data],
    )
    return result.results
```

TypeScript:

```typescript
import { Render } from "@renderinc/sdk";

task(
  { name: "orchestrate" },
  async function orchestrate(_ctx: TaskContext, data: object): Promise<unknown> {
    const render = new Render();
    const result = await render.workflows.runTask(
      "other-workflow/process",
      [data],
    );
    return result.results;
  },
);
```

Cross-workflow calls require an API key and are subject to Render API behavior. Prefer same-workflow chaining when the tasks form one logical execution graph.

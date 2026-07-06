# Render Claude plugin

Use Render from Claude Code to deploy apps, validate `render.yaml`, debug failed deploys, monitor services, and work through common platform workflows.

## What you get

- The Render MCP server preconfigured over OAuth (`.mcp.json`) so Claude can manage services, deploys, logs, metrics, and databases directly — no API key required
- Bundled Render skills for deployment, debugging, monitoring, migrations, and workflows (synced from [render-oss/skills](https://github.com/render-oss/skills))
- A `render-assistant` agent that specializes in Render deploys
- Slash commands: `/deploy-to-render` and `/check-render-status`
- A `PostToolUse` hook that validates `render.yaml` whenever you edit it
- Helper scripts at `scripts/` for skills sync and Blueprint validation

## Install the plugin

Add this repo as a Claude Code marketplace, then install the `render` plugin from it:

```
/plugin marketplace add render-oss/render-plugin-claude-code
/plugin install render
```

## Install locally for development

1. Clone this repo, then add it as a local marketplace:

```bash
git clone https://github.com/render-oss/render-plugin-claude-code.git
```

2. In Claude Code, point at the local checkout:

```
/plugin marketplace add ./render-plugin-claude-code
/plugin install render
```

3. Restart Claude Code if the plugin doesn't show up immediately.

## Get started

Use the plugin to:

- Deploy a project to Render
- Validate and troubleshoot `render.yaml`
- Debug failed deploys and check service status
- Work through common setup and migration tasks

Good first prompts:

- `Help me deploy this project to Render.`
- `Help me validate my render.yaml for Render.`
- `Debug a failed Render deployment.`

You can also run the slash commands directly:

- `/deploy-to-render`
- `/check-render-status`

## Set up the Render CLI

The plugin uses the Render CLI for live operations and Blueprint validation. Most workflows depend on it.

1. Install the Render CLI:

```bash
brew install render
```

2. Authenticate:

```bash
render login
```

3. Verify access:

```bash
render whoami -o json
```

If `render whoami -o json` fails, fix authentication before relying on Render workflows in Claude Code.

## MCP server

The plugin bundles Render's [MCP server](https://render.com/docs/mcp-server) through the `.mcp.json` at the repo root, so Claude can manage your Render services, deploys, logs, metrics, and databases directly.

Authentication is handled over OAuth — you don't need an API key. The first time Claude uses a Render MCP tool, it opens your browser to sign in to Render and authorize access to `https://mcp.render.com/mcp`. After you approve, Claude connects automatically on future runs.

The MCP server and the Render CLI (below) are complementary: MCP covers day-to-day service, log, metric, and database operations, while the CLI still backs Blueprint validation and other CLI-only workflows.

## For maintainers

Run the sync script to refresh `skills/` from [render-oss/skills](https://github.com/render-oss/skills):

```bash
./scripts/sync-skills.sh
```

GitHub Actions also runs `.github/workflows/sync-skills.yml` each day and opens a pull request when upstream skills change.

## License

MIT. See [LICENSE](LICENSE).

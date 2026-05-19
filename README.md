# Render Claude plugin

Use Render from Claude Code to deploy apps, validate `render.yaml`, debug failed deploys, monitor services, and work through common platform workflows.

## What you get

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

Render's MCP server isn't included in this plugin yet because it doesn't support OAuth. Once OAuth is available, the plugin will ship with an `.mcp.json` so Claude can use Render MCP tools directly. Until then, the plugin uses the Render CLI for service creation, log retrieval, metrics, and database inspection.

## For maintainers

Run the sync script to refresh `skills/` from [render-oss/skills](https://github.com/render-oss/skills):

```bash
./scripts/sync-skills.sh
```

GitHub Actions also runs `.github/workflows/sync-skills.yml` each day and opens a pull request when upstream skills change.

## License

MIT. See [LICENSE](LICENSE).

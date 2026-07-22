# Changelog

All notable changes to the Render plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-07-06

### Added

- Bundled the Render MCP server, preconfigured over OAuth (`.mcp.json`), so Claude can manage services, deploys, logs, metrics, and databases directly — no API key required.
- README section documenting the MCP server, its OAuth sign-in flow, and how it complements the Render CLI.

## [0.1.0] - Initial release

### Added

- Skills covering deploying, debugging, and monitoring applications on Render, including blueprints, web services, static sites, background workers, cron jobs, Postgres, key-value stores, disks, domains, networking, scaling, environment variables, Docker, private services, the Render CLI, and Heroku migration.
- `render-assistant` agent.
- `deploy-to-render` and `check-render-status` slash commands.
- `render.yaml` validation hook.

[0.2.0]: https://github.com/render-oss/render-plugin-claude-code/releases/tag/v0.2.0
[0.1.0]: https://github.com/render-oss/render-plugin-claude-code/releases/tag/v0.1.0

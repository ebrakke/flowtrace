# Release and Publishing Notes

## GitHub MVP checklist

1. Confirm `README.md`, `LICENSE`, and development docs are present.
2. Run validation:

   ```bash
   go test ./packages/cli/...
   go run ./packages/cli/cmd/flowtrace validate --root . examples/simple.flow.json
   ```

3. Create a GitHub repository at `github.com/flowtrace/flowtrace` or update the documented module/install path if the owner/name changes.
4. Push the repository and create an initial tag, for example `v0.1.0`.
5. Verify install from outside the checkout:

   ```bash
   go install github.com/flowtrace/flowtrace/packages/cli/cmd/flowtrace@v0.1.0
   ```

## Skills publishing checklist

1. Keep the canonical skill at `skills/flowtrace/SKILL.md`.
2. Validate with `skills-ref validate ./skills/flowtrace` when available.
3. After the GitHub repository is public, verify:

   ```bash
   npx skills add https://github.com/flowtrace/flowtrace --skill flowtrace
   ```

4. Submit or wait for skills.sh indexing according to the current skills.sh process.

## Current MVP limitations to mention in releases

- Search-only builds are heuristic and may mark nodes with `resolution: search`.
- LLM-assisted builds require Anthropic or OpenAI API keys.
- The Neovim plugin is installed from `packages/nvim` in a local checkout for now.

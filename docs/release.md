# Release and Publishing Notes

## GitHub MVP checklist

1. Confirm `README.md`, `LICENSE`, and development docs are present.
2. Run validation:

   ```bash
   go test ./packages/cli/...
   go run ./packages/cli/cmd/flowtrace validate --root . examples/simple.flow.json
   ```

3. Confirm the GitHub repository is public at `github.com/ebrakke/flowtrace`.
4. Push the repository and create an initial tag, for example `v0.1.0`.
5. Verify install from outside the checkout:

   ```bash
   go install github.com/ebrakke/flowtrace/packages/cli/cmd/flowtrace@v0.1.0
   ```

## Skills publishing checklist

1. Keep the canonical skill at `skills/flowtrace/SKILL.md`.
2. Validate with `skills-ref validate ./skills/flowtrace` when available.
3. After the GitHub repository is public, verify:

   ```bash
   npx skills add https://github.com/ebrakke/flowtrace --skill flowtrace
   ```

4. Submit or wait for skills.sh indexing according to the current skills.sh process.

## Current MVP limitations to mention in releases

- `flowtrace build` is a deterministic search scaffold and may mark nodes with `resolution: search`.
- High-quality flows are expected to be authored by the calling coding agent, then validated with the CLI.
- The Neovim plugin lives in `packages/nvim`, so lazy.nvim installs from the public repo with a small runtimepath config block.

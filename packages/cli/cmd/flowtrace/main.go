package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/ebrakke/flowtrace/packages/cli/internal/core"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	var err error
	switch os.Args[1] {
	case "build":
		err = runBuild(os.Args[2:])
	case "context":
		err = runContext(os.Args[2:])
	case "validate":
		err = runValidate(os.Args[2:])
	case "print":
		err = runPrint(os.Args[2:])
	case "help", "-h", "--help":
		usage()
	default:
		err = fmt.Errorf("unknown command %q", os.Args[1])
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "flowtrace:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `flowtrace - build jumpable code walkthroughs

Usage:
  flowtrace build [options] "request"
  flowtrace context [options] "request"
  flowtrace validate [--root DIR] FILE.flow.json
  flowtrace print FILE.flow.json

Commands:
  build     search the repo and emit a deterministic scaffold .flow.json
  context   print candidate repository context for an agent-authored flow
  validate  validate schema references and file/line locations
  print     render a flow tree in the terminal`)
}

func runBuild(args []string) error {
	fs := flag.NewFlagSet("build", flag.ContinueOnError)
	root := fs.String("root", ".", "repository root")
	out := fs.String("out", "", "output .flow.json path")
	maxFiles := fs.Int("max-files", 80, "maximum candidate files")
	maxNodes := fs.Int("max-nodes", 40, "maximum flow nodes")
	dryRun := fs.Bool("dry-run", false, "print candidate context but do not write artifact")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 {
		return fmt.Errorf("build requires one natural-language request")
	}
	return core.Build(core.BuildOptions{Root: *root, Out: *out, MaxFiles: *maxFiles, MaxNodes: *maxNodes, DryRun: *dryRun, Request: fs.Arg(0)})
}

func runContext(args []string) error {
	fs := flag.NewFlagSet("context", flag.ContinueOnError)
	root := fs.String("root", ".", "repository root")
	maxFiles := fs.Int("max-files", 80, "maximum candidate files")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 {
		return fmt.Errorf("context requires one natural-language request")
	}
	return core.Build(core.BuildOptions{Root: *root, MaxFiles: *maxFiles, DryRun: true, Request: fs.Arg(0)})
}

func runValidate(args []string) error {
	fs := flag.NewFlagSet("validate", flag.ContinueOnError)
	root := fs.String("root", ".", "repository root")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 {
		return fmt.Errorf("validate requires a .flow.json file")
	}
	flow, err := core.LoadFlow(fs.Arg(0))
	if err != nil {
		return err
	}
	return core.ValidateFlow(flow, *root)
}

func runPrint(args []string) error {
	fs := flag.NewFlagSet("print", flag.ContinueOnError)
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() != 1 {
		return fmt.Errorf("print requires a .flow.json file")
	}
	flow, err := core.LoadFlow(fs.Arg(0))
	if err != nil {
		return err
	}
	core.PrintFlow(os.Stdout, flow)
	return nil
}

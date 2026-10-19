//go:build linux

package main

import (
	"fmt"
	"os"
	"os/exec"
)

// go run main.go run <cmd> <args>
func main() {
	if len(os.Args) < 3 {
		fmt.Println("usage: go run main.go run <cmd> [args...]")
		os.Exit(1)
	}

	switch os.Args[1] {
	case "run":
		run()
	default:
		panic("help")
	}
}

func run() {
	fmt.Printf("Running %v \n", os.Args[2:])

	cmd := exec.Command(os.Args[2], os.Args[3:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	cmd.Run()
}

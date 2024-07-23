//go:build linux
// +build linux

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"
)

// go run main.go run <cmd> <args>
func main() {
	switch os.Args[1] {
	case "run":
		run()
	case "child":
		child()
	default:
		panic("help")
	}
}

func run() {
	fmt.Printf("Running %v as %d\n", os.Args[2:], os.Getpid())

	cmd := exec.Command("/proc/self/exe", append([]string{"child"}, os.Args[2:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Cloneflags:   syscall.CLONE_NEWUTS | syscall.CLONE_NEWPID | syscall.CLONE_NEWNS,
		Unshareflags: syscall.CLONE_NEWNS,
	}

	cmd.Run()
}

func child() {
	fmt.Printf("Running %v as %d\n", os.Args[2:], os.Getpid())

	cg()

	cmd := exec.Command(os.Args[2], os.Args[3:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	syscall.Sethostname([]byte("container"))
	syscall.Chroot("/opt/container-filesystem")
	os.Chdir("/")
	syscall.Mount("proc", "proc", "proc", 0, "")

	cmd.Run()

	syscall.Unmount("proc", 0)
}

func cg() {
	cgroupPath := "/sys/fs/cgroup"

	// Allow control for pids in the cgroup subtree
	err := os.WriteFile(filepath.Join(cgroupPath, "cgroup.subtree_control"), []byte("+pids"), 0700)
	if err != nil {
		panic(err)
	}

	cgroupDemoPath := "/sys/fs/cgroup/containerdemo"
	err = os.Mkdir(cgroupDemoPath, 0755)
	if err != nil && !os.IsExist(err) {
		panic(err)
	}

	// Make this cgroup "threaded"
	err = os.WriteFile(filepath.Join(cgroupDemoPath, "cgroup.type"), []byte("threaded"), 0700)
	if err != nil {
		panic(err)
	}

	// Allow maximal 20 pids
	err = os.WriteFile(filepath.Join(cgroupDemoPath, "pids.max"), []byte("20"), 0700)
	if err != nil {
		panic(err)
	}

	// add current pis to the cgroup
	pid := strconv.Itoa(os.Getpid())
	if err := os.WriteFile(filepath.Join(cgroupDemoPath, "cgroup.threads"), []byte(pid), 0700); err != nil {
		panic(err)
	}

}

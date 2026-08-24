package operations

import (
	"os"
	"syscall"
)

func syscallFlock(fd *os.File) error {
	return syscall.Flock(int(fd.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
}

func syscallFlockUnlock(fd *os.File) error {
	return syscall.Flock(int(fd.Fd()), syscall.LOCK_UN)
}

.PHONY: all build build/quick install clean test lint vet run help

BINARY    = ivali
GO        = go
CGO       = CGO_ENABLED=0
GOFLAGS   = -ldflags="-s -w"
GOPACKAGES = ./cmd/$(BINARY)

all: build

build:
	$(CGO) $(GO) build $(GOFLAGS) -o $(BINARY) $(GOPACKAGES)
	@echo "  built  ./$(BINARY)"

build/quick:
	$(CGO) $(GO) build -o $(BINARY) $(GOPACKAGES)
	@echo "  built  ./$(BINARY) (no optimisations)"

install:
	$(CGO) $(GO) install $(GOFLAGS) $(GOPACKAGES)
	@echo "  installed  $$(which $(BINARY))"

clean:
	rm -f $(BINARY)
	$(GO) clean
	@echo "  cleaned"

test:
	$(CGO) $(GO) test -v -race -count=1 ./...
	@echo "  tests  passed"

lint:
	golangci-lint run ./... || true
	@echo "  lint  done"

vet:
	$(CGO) $(GO) vet ./...
	@echo "  vet  passed"

run: build
	@./$(BINARY)

deps:
	$(GO) mod tidy
	$(GO) mod verify
	@echo "  deps  resolved"

help:
	@./$(BINARY) --help

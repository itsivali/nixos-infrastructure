.PHONY: all build build/quick install clean test lint vet run help

BINARY     = ivali
BINARY_BW  = bw-tui
GO         = go
CGO        = CGO_ENABLED=0
GOFLAGS    = -ldflags="-s -w"
GOPACKAGES = ./cmd/$(BINARY)
GOPACKAGES_BW = ./cmd/$(BINARY_BW)

all: build build-bw

build:
	$(CGO) $(GO) build $(GOFLAGS) -o $(BINARY) $(GOPACKAGES)
	@echo "  built  ./$(BINARY)"

build/quick:
	$(CGO) $(GO) build -o $(BINARY) $(GOPACKAGES)
	@echo "  built  ./$(BINARY) (no optimisations)"

build-bw:
	$(CGO) $(GO) build $(GOFLAGS) -o $(BINARY_BW) $(GOPACKAGES_BW)
	@echo "  built  ./$(BINARY_BW)"

build-bw/quick:
	$(CGO) $(GO) build -o $(BINARY_BW) $(GOPACKAGES_BW)
	@echo "  built  ./$(BINARY_BW) (no optimisations)"

install:
	$(CGO) $(GO) install $(GOFLAGS) $(GOPACKAGES)
	$(CGO) $(GO) install $(GOFLAGS) $(GOPACKAGES_BW)
	@echo "  installed  $$(which $(BINARY)) and $$(which $(BINARY_BW))"

clean:
	rm -f $(BINARY) $(BINARY_BW)
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

run-bw: build-bw
	@echo "Run: ./$(BINARY_BW)"
	@true

deps:
	$(GO) mod tidy
	$(GO) mod verify
	@echo "  deps  resolved"

help:
	@./$(BINARY) --help

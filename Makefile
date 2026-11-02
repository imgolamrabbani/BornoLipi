.PHONY: all build install run clean

all: build

build:
	@chmod +x build.sh
	@./build.sh

install: build
	@rm -rf "/Applications/BornoLipi.app"
	@cp -R "build/BornoLipi.app" "/Applications/BornoLipi.app"
	@echo "✅ Installed to /Applications/BornoLipi.app"

run: install
	@open "/Applications/BornoLipi.app"

clean:
	@rm -rf build

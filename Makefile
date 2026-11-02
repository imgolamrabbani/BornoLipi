.PHONY: all build fonts install run clean

all: build

build:
	@chmod +x build.sh
	@./build.sh

fonts:
	@mkdir -p "$(HOME)/Library/Fonts"
	@unzip -j -o "Fonts.zip" -d "$(HOME)/Library/Fonts"
	@echo "✅ Installed all Bangla fonts (SutonnyMJ, SutonnyOMJ, etc.) to ~/Library/Fonts/"

install: build fonts
	@rm -rf "/Applications/BornoLipi.app"
	@cp -R "build/BornoLipi.app" "/Applications/BornoLipi.app"
	@echo "✅ Installed to /Applications/BornoLipi.app"

run: install
	@open "/Applications/BornoLipi.app"

clean:
	@rm -rf build

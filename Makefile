.PHONY: project lint test beta release clean

# Regenerate the Xcode project from project.yml (run after cloning or editing project.yml)
project:
	xcodegen generate

# Lint everything (CI uses the same command with --strict)
lint:
	swiftlint lint --strict

# Run the full unit + UI test suite on a locally available iPhone simulator
test:
	bundle exec fastlane test

# Build and upload to TestFlight (requires signing setup — see README.md)
beta:
	bundle exec fastlane beta

# Build and submit to the App Store (run by CI on a v* tag)
release:
	bundle exec fastlane release

clean:
	rm -rf BetterContacts.xcodeproj fastlane/test_output

#!/bin/sh

# $1 - SchemeName
# $2 - Configuration (BetaTestDev, BetaTestUAT)
buildBrand() {
  echo "Building $1"
  xctool -workspace QuickAuctions/QuickAuctions.xcworkspace \
    -scheme "$1" -sdk iphoneos -configuration "$2" \
    build \
    OBJROOT="$PWD/build/$1" \
    SYMROOT="$PWD/build/$1" \
    ONLY_ACTIVE_ARCH=NO
  # TODO: Only output if there's an error?
}

runUnitTests() {
  echo "Running Unit Tests"
  xcodebuild -workspace QuickAuctions/QuickAuctions.xcworkspace \
    -scheme QuickAuctions-Dev \
    -sdk iphonesimulator \
    -configuration BetaTestDev \
    -destination "platform=iOS Simulator,name=iPhone 6,OS=9.0" \
	build \
    test \
	| xcpretty
}

if [[ $# == 2 ]]; then
  rm -r $PWD/build
  buildBrand "$1" "$2"
elif [[ "$TRAVIS_BRANCH" != z-deploy-*-uat ]]; then
  # only perform these builds on branches other than UAT deploys

  echo "Cleaning $PWD/build directory"
  rm -r $PWD/build

  # buildBrand <schemeName> <configuration>
  #buildBrand QuickAuctions-Dev BetaTestDev
  # buildBrand Phillips-Dev BetaTestDev
  # buildBrand HartDavisHart-Dev BetaTestDev
  # specify any additional brands below
  runUnitTests
else
  echo "UAT Deploy Branch -- skipping core validations"
fi

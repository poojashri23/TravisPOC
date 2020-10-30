#!/bin/sh

openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/dist-cert.p12.enc -d -a -out scripts/certs/dist-cert.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/apple-dist-cert.p12.enc -d -a -out scripts/certs/apple-dist-cert.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/hdh.p12.enc -d -a -out scripts/certs/hdh.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/phillips-cert-key.p12.enc -d -a -out scripts/certs/phillips-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/thomaston-cert-key.p12.enc -d -a -out scripts/certs/thomaston-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/posters-cert-key.p12.enc -d -a -out scripts/certs/posters-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/acker-cert-key.p12.enc -d -a -out scripts/certs/acker-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/stacksbowers-cert-key.p12.enc -d -a -out scripts/certs/stacksbowers-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/wright-cert-key.p12.enc -d -a -out scripts/certs/wright-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/zachys-cert-key.p12.enc -d -a -out scripts/certs/zachys-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/ogclearinghouse-cert-key.p12.enc -d -a -out scripts/certs/ogclearinghouse-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/affiliatedauctions-cert-key.p12.enc -d -a -out scripts/certs/affiliatedauctions-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/dupuis-cert-key.p12.enc -d -a -out scripts/certs/dupuis-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/spectrum-cert-key.p12.enc -d -a -out scripts/certs/spectrum-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/jpking-cert-key.p12.enc -d -a -out scripts/certs/jpking-cert-key.p12
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/keyauctioneers-cert-key.p12.enc -d -a -out scripts/certs/keyauctioneers-cert-key.p12
# add additional decryption certs below

# Create custom keychain
security create-keychain -p $CUSTOM_KEYCHAIN_PASSWORD ios-build.keychain

security import ./scripts/certs/apple.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
# AM cert
security import ./scripts/certs/dist-cert.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
security import ./scripts/certs/apple-dist-cert.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# HDH cert
security import ./scripts/certs/hdh.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# Phillips cert
security import ./scripts/certs/phillips-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# Thomaston cert
security import ./scripts/certs/thomaston-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# Posters cert
security import ./scripts/certs/posters-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# Acker cert
security import ./scripts/certs/acker-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# StacksBowers cert
security import ./scripts/certs/stacksbowers-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# Wright cert
security import ./scripts/certs/wright-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# Zachys cert
security import ./scripts/certs/zachys-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# OGClearinghouse cert
security import ./scripts/certs/ogclearinghouse-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# AffiliatedAuctions cert
security import ./scripts/certs/affiliatedauctions-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# Dupuis cert
security import ./scripts/certs/dupuis-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# SpectrumWine cert
security import ./scripts/certs/spectrum-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# JPKing cert
security import ./scripts/certs/jpking-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
# KeyAuctioneers cert
security import ./scripts/certs/keyauctioneers-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign


# Make the ios-build.keychain default, so xcodebuild will use it
security default-keychain -s ios-build.keychain-db
# Unlock the keychain
security unlock-keychain -p $CUSTOM_KEYCHAIN_PASSWORD ios-build.keychain-db
# Set keychain timeout to 1 hour for long builds
# see here
security set-keychain-settings -t 36000 -l ~/Library/Keychains/ios-build.keychain-db

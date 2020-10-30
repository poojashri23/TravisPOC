# How to add a new client build to Travis

1) Export Signing Certificate from KeyChain (Right click on the private key in the cert and export that as .p12 file). This will provide the signed cert + the key. Use the `KEY_PASSWORD` value for the password

2) Encrypt the resulting .p12 file using the following commands:

```
openssl aes-256-cbc -k "<ENCRYPTION PASSWORD>" -in scripts/certs/cert-filename.p12 -out scripts/certs/cert-filename.p12.enc -a
```
Replace `cert-filename` with an appropriate name

3) Edit `scripts/travis/add-key.sh`

Add similar entry as others to decrypt the certificate and also import. Examples of the two lines you'd be adding are below. **Be sure to modify the actual filename that's used!**

```
openssl aes-256-cbc -k "$ENCRYPTION_SECRET" -in scripts/certs/thomaston-cert-key.p12.enc -d -a -out scripts/certs/thomaston-cert-key.p12
```

and in the middle:

```
security import ./scripts/certs/thomaston-cert-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $KEY_PASSWORD -T /usr/bin/codesign
```

4) (Optional) Add an entry in `scripts/travis/build-brands.sh` so that the DEV version of your new brand is built on every run

You just need to add a new line that builds the actual target in the appropriate place, i.e.:
```
buildBrand Thomaston-Dev BetaTestDev
```

5) (Optional) Add deployment triggers for your new brand

Scroll down to the bottom, and add a new entry for DEV and UAT:

DEV would look like the following:
```
if [[ "$TRAVIS_BRANCH" == "z-deploy-thomaston-dev" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Hart Davis Hart Wine Company (KCNUH456X5)"
  signAndUpload Thomaston \
    Thomaston-Dev \
    BetaTestDev \
    <hockeyapp app id> \
    <crittercism api key> \
    <crittercism app id>
fi
```

(Note that crittercism key + id are optional)

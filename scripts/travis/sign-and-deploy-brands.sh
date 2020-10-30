#!/bin/bash

BUILD_BRANDS_SH="$( cd "$( dirname "$0" )" && pwd )/build-brands.sh"

if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then
  echo "This is a pull request. No deployment will be done."
  exit 0
fi

if [[ "$TRAVIS_COMMIT_RANGE" == "" ]]; then
  echo "Using fallback for commit range (last commit)."
  COMMIT_RANGE="HEAD^..HEAD"
else
  # TRAVIS_COMMIT_RANGE is in the wrong format.. tweak it for us...
  COMMIT_RANGE=`echo $TRAVIS_COMMIT_RANGE | sed 's/\.\.\./../'`
fi
echo "COMMIT RANGE: $COMMIT_RANGE"

COMMIT_HISTORY=`git log --pretty=oneline --abbrev-commit "$COMMIT_RANGE"`

RELEASE_DATE=`date '+%Y-%m-%d %H:%M:%S'`

if [[ "$TRAVIS_BRANCH" != *-dev ]]; then
  # Simplify release notes for non-dev builds (skip commit history)
  RELEASE_NOTES="Build: $TRAVIS_BUILD_NUMBER
  Git Commit: $TRAVIS_COMMIT ($TRAVIS_COMMIT_RANGE)
  Uploaded: $RELEASE_DATE"
else
  RELEASE_NOTES="Build: $TRAVIS_BUILD_NUMBER
  Git Commit: $TRAVIS_COMMIT ($TRAVIS_COMMIT_RANGE)
  Uploaded: $RELEASE_DATE

  Changes since last deployed build:
  $COMMIT_HISTORY"
fi

# Set a default dev name
DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"

# signAndUpload - Sign the app, then upload to HockeyApp
# signAndUpload <appName> <schemeName> <configuration> <hockeyApp-appId> <mint/splunt app key>
signAndUpload() {

  echo "**************************"
  echo "**  Signing $2"
  echo "**************************"

  OUTPUTDIR="$PWD/build/$2/$3-iphoneos"
  PROVISIONING_PROFILE="$HOME/Library/MobileDevice/Provisioning Profiles/$2.mobileprovision"

  xcrun -log -sdk iphoneos PackageApplication "$OUTPUTDIR/$1.app" \
    -o "$OUTPUTDIR/$1.ipa" -sign "$DEVELOPER_NAME" -embed "$PROVISIONING_PROFILE"

  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${TRAVIS_BUILD_NUMBER}" "$OUTPUTDIR/$1.app.dSYM/Contents/Info.plist"
  
  zip -r "$OUTPUTDIR/$1.dSYM.zip" "$OUTPUTDIR/$1.app.dSYM"

  echo "**************************"
  echo "** Uploading $2"
  echo "**************************"
  curl https://rink.hockeyapp.net/api/2/apps/$4/app_versions/upload \
    -F status="2" \
    -F notify="0" \
    -F notes="$RELEASE_NOTES" \
    -F notes_type="0" \
    -F private=true \
    -F tags=internal \
    -F ipa="@$OUTPUTDIR/$1.ipa" \
    -F dsym="@$OUTPUTDIR/$1.dSYM.zip" \
    -H "X-HockeyAppToken: $HOCKEYAPP_API_TOKEN"

  echo "\n"
  echo "UPLOADING dSYM to S3"
  file="$OUTPUTDIR/$1.dSYM.zip"
  uploadedFile="$1-$TRAVIS_BUILD_NUMBER-$(date -u +"%Y-%m-%d-%H%M%S").dSYM.zip"
  bucket="auctionmobility-internal-engineering"
  resource="/${bucket}/ios/dSYM/${uploadedFile}"
  contentType="application/zip"
  dateValue="$(LC_ALL=C date -u +"%a, %d %b %Y %X %z")"
  stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
  s3Key="AKIAJ24S4P2PTRIZQJCA"
  s3Secret=$S3_ACCESS_SECRET
  signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3Secret} -binary | base64`
  # FIXME: TEMPORARY HACK TO UPLOAD dSYM
  # Instead of using the signature logic above that fails, use a unique user-agent string
  # with perms to put objects...
  curl -X PUT -T "${file}" \
    -H "Host: ${bucket}.s3.amazonaws.com" \
    -H "Date: ${dateValue}" \
    -H "Content-Type: ${contentType}" \
    -H "User-agent: QvpTiameJ1G116tM2MP3" \
    https://${bucket}.s3.amazonaws.com/ios/dSYM/${uploadedFile}

  echo "dSYM should be available at : https://${bucket}.s3.amazonaws.com/ios/dSYM/${uploadedFile}"
}

# deploy if special branches have been triggered
if [[ "$TRAVIS_BRANCH" == "z-deploy-demo-dev" ]]; then
  signAndUpload QuickAuctions QuickAuctions-Dev BetaTestDev 77a7f55260ef5509730b0490bc48cfaf
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-demo-uat" ]]; then
  $BUILD_BRANDS_SH QuickAuctions-UAT BetaTestUAT
  signAndUpload QuickAuctions QuickAuctions-UAT BetaTestUAT 5d97e48172895917342da6624f8cd895
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-rogallery-dev" ]]; then
  signAndUpload RoGallery "RoGalleryAuctions-Dev" BetaTestDev bccbb1acb73a07203d8ecff7d52303e9
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-rogallery-uat" ]]; then
  $BUILD_BRANDS_SH "RoGalleryAuctions-UAT" BetaTestUAT
  signAndUpload RoGallery "RoGalleryAuctions-UAT" BetaTestUAT ec12610607328bf407f2c820fad86d71
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-phillips-dev" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Phillips Auctioneers LLC (LQK23KRCDB)"
  signAndUpload Phillips Phillips-Dev BetaTestDev 0dd55238b84c471d0ecc9288d32d13d0
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-phillips-uat" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Phillips Auctioneers LLC (LQK23KRCDB)"
  $BUILD_BRANDS_SH Phillips-UAT BetaTestUAT
  signAndUpload Phillips Phillips-UAT BetaTestUAT 99740264f3c678db83ff6eb49c43eedf
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-phillips-training" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Phillips Auctioneers LLC (LQK23KRCDB)"
  $BUILD_BRANDS_SH Phillips-Training BetaTestTraining
  signAndUpload Phillips Phillips-Training BetaTestTraining aafabe8cffca4058a44214f63990e048
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-hdh-dev" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Hart Davis Hart Wine Company (KCNUH456X5)"
  signAndUpload HartDavisHart \
    HartDavisHart-Dev \
    BetaTestDev \
    c8882a6cbbf99135c826fa920cfe023d
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-hdh-uat" ]]; then
  $BUILD_BRANDS_SH HartDavisHart-UAT BetaTestUAT
  DEVELOPER_NAME="iPhone Distribution: Hart Davis Hart Wine Company (KCNUH456X5)"
  signAndUpload HartDavisHart \
    HartDavisHart-UAT \
    BetaTestUAT \
    14f61a361fc6085ba830e4038cb4a288
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-thomaston-dev" ]]; then
  DEVELOPER_NAME="iPhone Distribution: THOMASTON PLACE AUCTION GALLERIES, INC (VKHAUH5L7G)"
  signAndUpload Thomaston \
    Thomaston-Dev \
    BetaTestDev \
    3950e1c60cedc2eb5785ecc2e1f24959
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-thomaston-uat" ]]; then
  $BUILD_BRANDS_SH Thomaston-UAT BetaTestUAT
  DEVELOPER_NAME="iPhone Distribution: THOMASTON PLACE AUCTION GALLERIES, INC (VKHAUH5L7G)"
  signAndUpload Thomaston \
    Thomaston-UAT \
    BetaTestUAT \
    83e9a690005f9966b392731927b5c301
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-copley-dev" ]]; then
  $BUILD_BRANDS_SH Copley-Dev BetaTestDev
  signAndUpload Copley Copley-Dev BetaTestDev 46abc79f855f40ae185285dbc7a3058a
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-copley-uat" ]]; then
  $BUILD_BRANDS_SH Copley-UAT BetaTestUAT
  signAndUpload Copley Copley-UAT BetaTestUAT 689f5a3cee974382766492dc424ff15b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-juliens-dev" ]]; then
  $BUILD_BRANDS_SH JuliensAuctions-Dev BetaTestDev
  signAndUpload JuliensAuctions \
    JuliensAuctions-Dev \
    BetaTestDev \
    86f64db77304153410fd387effbc3ef2
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-juliens-uat" ]]; then
  $BUILD_BRANDS_SH JuliensAuctions-UAT BetaTestUAT
  signAndUpload JuliensAuctions \
    JuliensAuctions-UAT \
    BetaTestUAT \
    ad4fd81dbda809aff726e4b84c60a408
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-posters-dev" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Poster Auctions International Inc (56K7CU6BKF)"
  $BUILD_BRANDS_SH PostersInternationalAuctions-Dev BetaTestDev
  signAndUpload PosterAuctionsIntl PostersInternationalAuctions-Dev BetaTestDev 250b1b068ac442eecce101928fb6af52
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-posters-uat" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Poster Auctions International Inc (56K7CU6BKF)"
  $BUILD_BRANDS_SH PostersInternationalAuctions-UAT BetaTestUAT
  signAndUpload PosterAuctionsIntl PostersInternationalAuctions-UAT BetaTestUAT 1d0468f532de582b9ba526396f944be8
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-acker-dev" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Acker, Merrall & Condit Company Inc (YKF2798FVU)"
  $BUILD_BRANDS_SH Acker-Dev BetaTestDev
  signAndUpload Acker Acker-Dev BetaTestDev 4678fee6826bc11f4b64a0859557ec18
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-acker-uat" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Acker, Merrall & Condit Company Inc (YKF2798FVU)"
  $BUILD_BRANDS_SH Acker-UAT BetaTestUAT
  signAndUpload Acker Acker-UAT BetaTestUAT c22655397226d2aacc629f1c15fae859
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-alexanderhistorical-uat" ]]; then
  $BUILD_BRANDS_SH AlexanderHistorical-UAT BetaTestUAT
  signAndUpload AlexanderHistorical AlexanderHistorical-UAT BetaTestUAT 4fb13f9c432c195b839d55d71e5fda35
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-americasbestauctioneer-uat" ]]; then
  $BUILD_BRANDS_SH AmericasBestAuctioneer-UAT BetaTestUAT
  signAndUpload AmericasBestAuctioneer AmericasBestAuctioneer-UAT BetaTestUAT 1d1c26ceb11ac6fbfbdb2bca702d9a31
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-converse-uat" ]]; then
  $BUILD_BRANDS_SH Converse-UAT BetaTestUAT
  signAndUpload Converse Converse-UAT BetaTestUAT 2564a779487e25f43f04fea1f3e23d4f
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-nesteggauctions-uat" ]]; then
  $BUILD_BRANDS_SH NestEggAuctions-UAT BetaTestUAT
  signAndUpload NestEggAuctions NestEggAuctions-UAT BetaTestUAT 734722ad99d1e049b7313702bd258e39
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-roschmitt-uat" ]]; then
  $BUILD_BRANDS_SH ROSchmitt-UAT BetaTestUAT
  signAndUpload ROSchmitt ROSchmitt-UAT BetaTestUAT 27238e7a6836b0057280041808c5a2cd
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-tradewinds-uat" ]]; then
  $BUILD_BRANDS_SH Tradewinds-UAT BetaTestUAT
  signAndUpload Tradewinds Tradewinds-UAT BetaTestUAT 818f39b444e0acdaa81467c3e4fe40b5
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-altair-uat" ]]; then
  $BUILD_BRANDS_SH Altair-UAT BetaTestUAT
  signAndUpload Altair Altair-UAT BetaTestUAT d005cc5899a0e243df6f6c421a151d34
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-langs-uat" ]]; then
  $BUILD_BRANDS_SH Langs-UAT BetaTestUAT
  signAndUpload Langs Langs-UAT BetaTestUAT 52932c5ae9349156cc20d3890baf8ba5
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-salesdemo-uat" ]]; then
  $BUILD_BRANDS_SH SalesDemo-UAT BetaTestUAT
  signAndUpload SalesDemo SalesDemo-UAT BetaTestUAT 0c00725e76267d574f7190d467e7546b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-stacksbowers-uat" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Spectrum Group International, Inc (64QVL98RFT)"
  $BUILD_BRANDS_SH StacksBowers-UAT BetaTestUAT
  signAndUpload StacksBowers StacksBowers-UAT BetaTestUAT c4f4375f21db5d9ac6e454c3c2c15a8c
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-stacksbowers-dev" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Spectrum Group International, Inc (64QVL98RFT)"
  $BUILD_BRANDS_SH StacksBowers-Dev BetaTestDev
  signAndUpload StacksBowers StacksBowers-Dev BetaTestDev 479b5c91f1d35269dd05b31d76df96d9
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-grogan-uat" ]]; then
  $BUILD_BRANDS_SH Grogan-UAT BetaTestUAT
  signAndUpload Grogan Grogan-UAT BetaTestUAT d663d038542871b886de624cf4f9a1e5
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-dargate-uat" ]]; then
  $BUILD_BRANDS_SH Dargate-UAT BetaTestUAT
  signAndUpload Dargate Dargate-UAT BetaTestUAT 222c27893acd18e28fd3958095d973ae
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-keno-uat" ]]; then
  $BUILD_BRANDS_SH Keno-UAT BetaTestUAT
  signAndUpload Keno Keno-UAT BetaTestUAT cef5720940083be83d3514700e2e1a44
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-harlanjberk-uat" ]]; then
  $BUILD_BRANDS_SH HarlanJBerk-UAT BetaTestUAT
  signAndUpload HarlanJBerk HarlanJBerk-UAT BetaTestUAT d8db2eea1e0cc5f87d5b7701f847622b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-graysauctioneers-uat" ]]; then
  $BUILD_BRANDS_SH GraysAuctioneers-UAT BetaTestUAT
  signAndUpload GraysAuctioneers GraysAuctioneers-UAT BetaTestUAT 033f18adaba8fa9fbd2ed9ab2fbe2890
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-zachys-uat" ]]; then
  DEVELOPER_NAME="iPhone Distribution: Zachys Wine Auctions, Inc (329EUPG42K)"
  $BUILD_BRANDS_SH Zachys-UAT BetaTestUAT
  signAndUpload Zachys Zachys-UAT BetaTestUAT 38219cd7f6b3057e1b0c5dccc69141e7
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-bostonauctions-uat" ]]; then
  $BUILD_BRANDS_SH BostonAuctions-UAT BetaTestUAT
  signAndUpload BostonAuctions BostonAuctions-UAT BetaTestUAT 6d4d8520be588d0fb18ff16ace9890d4
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-rasmus-uat" ]]; then
  $BUILD_BRANDS_SH Rasmus-UAT BetaTestUAT
  signAndUpload Rasmus Rasmus-UAT BetaTestUAT 60efb9eebe8cfcab99c24836d6604d36
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-ableauctions-uat" ]]; then
  $BUILD_BRANDS_SH AbleAuctions-UAT BetaTestUAT
  signAndUpload AbleAuctions AbleAuctions-UAT BetaTestUAT 01eda312de471a92e05e53b690a6b87e
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-estatesales-uat" ]]; then
  $BUILD_BRANDS_SH EstateSales-UAT BetaTestUAT
  signAndUpload EstateSales EstateSales-UAT BetaTestUAT a74491d0fe7c40da6eadd686f9cd80fc
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-sandwichauctionhouse-uat" ]]; then
  $BUILD_BRANDS_SH SandwichAuctionHouse-UAT BetaTestUAT
  signAndUpload SandwichAuctionHouse SandwichAuctionHouse-UAT BetaTestUAT 7a75bd739bc188e310746383c7ce5db7
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-888auctions-uat" ]]; then
  $BUILD_BRANDS_SH 888Auctions-UAT BetaTestUAT
  signAndUpload 888Auctions 888Auctions-UAT BetaTestUAT 58f526c0c1f95c3abe5a75147a38fca8
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-alexcooper-uat" ]]; then
  $BUILD_BRANDS_SH AlexCooper-UAT BetaTestUAT
  signAndUpload AlexCooper AlexCooper-UAT BetaTestUAT 62609741c47cae1f59bb451399f15134
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-kwikauctions-uat" ]]; then
  $BUILD_BRANDS_SH KwikAuctions-UAT BetaTestUAT
  signAndUpload KwikAuctions KwikAuctions-UAT BetaTestUAT 5720489a8b8525dea60a5966629e4540
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-bonhams-uat" ]]; then
  $BUILD_BRANDS_SH Bonhams-UAT BetaTestUAT
  signAndUpload Bonhams Bonhams-UAT BetaTestUAT e19470b203ef0dc8ffe9fcc251fcbe5b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-wright-uat" ]]; then
  DEVELOPER_NAME="iPhone Distribution: R. Wright Inc. (CM8J743ETS)"
  $BUILD_BRANDS_SH Wright-UAT BetaTestUAT
  signAndUpload Wright Wright-UAT BetaTestUAT b0a5a2d1b44cd18b4c5fcee3b6fa7a06
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-ogclearinghouse-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Charles Koch (7EWQGBR2RQ)"
  $BUILD_BRANDS_SH OGClearinghouse-UAT BetaTestUAT
  signAndUpload OGClearinghouse OGClearinghouse-UAT BetaTestUAT a90ff202104cc8273c944f4fb0305b7b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-ogclearinghouse-dev" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Charles Koch (7EWQGBR2RQ)"
  $BUILD_BRANDS_SH OGClearinghouse-Dev BetaTestDev
  signAndUpload OGClearinghouse OGClearinghouse-Dev BetaTestDev cf34add76a5b16e1344d25c954e5b840
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-kwikauctions-uat" ]]; then
  $BUILD_BRANDS_SH KwikAuctions-UAT BetaTestUAT
  signAndUpload KwikAuctions KwikAuctions-UAT BetaTestUAT 5720489a8b8525dea60a5966629e4540
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-affiliatedauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Affiliated Auctions (EPS52HLYP6)"
  $BUILD_BRANDS_SH AffiliatedAuctions-UAT BetaTestUAT
  signAndUpload AffiliatedAuctions AffiliatedAuctions-UAT BetaTestUAT 0b11c1df6bf899a68efe04a7c8fde4ea
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-antiqueadvertising-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH AntiqueAdvertising-UAT BetaTestUAT
  signAndUpload AntiqueAdvertising AntiqueAdvertising-UAT BetaTestUAT 17813cdb89979d1b4599faec04004c18
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-alexanderhistorical-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH AlexanderHistorical-UAT BetaTestUAT
  signAndUpload AlexanderHistorical AlexanderHistorical-UAT BetaTestUAT 4fb13f9c432c195b839d55d71e5fda35
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-americanauctionassociates-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH AmericanAuctionAssociates-UAT BetaTestUAT
  signAndUpload AmericanAuctionAssociates AmericanAuctionAssociates-UAT BetaTestUAT 0a9871f144421749b94794117e587e0b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-heathindustrial-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH HeathIndustrial-UAT BetaTestUAT
  signAndUpload HeathIndustrial HeathIndustrial-UAT BetaTestUAT 7faeeda8de0d9f764f930d09fb3d3516
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-palmbeachmodern-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH PalmBeachModern-UAT BetaTestUAT
  signAndUpload PalmBeachModern PalmBeachModern-UAT BetaTestUAT 7e9296563e7f3ce87d70f9b84ae944b9
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-jsugarman-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH JSugarman-UAT BetaTestUAT
  signAndUpload JSugarman JSugarman-UAT BetaTestUAT 34b549ce9d2a3f75143d83299558a7ae
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-lauro-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH Lauro-UAT BetaTestUAT
  signAndUpload Lauro Lauro-UAT BetaTestUAT aecad412432034922b3367602920726c
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-hollyauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH HollyAuctions-UAT BetaTestUAT
  signAndUpload HollyAuctions HollyAuctions-UAT BetaTestUAT 54fc280b7f36836d946793baac3d707f
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-genco-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH Genco-UAT BetaTestUAT
  signAndUpload Genco Genco-UAT BetaTestUAT d067afa03c434aa5b1d0729fd85e2009
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-christies-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH Christies-UAT BetaTestUAT
  signAndUpload Christies Christies-UAT BetaTestUAT 63cb16210b8049659dadf137906981a6
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-cowbuyer-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH CowBuyer-UAT BetaTestUAT
  signAndUpload CowBuyer CowBuyer-UAT BetaTestUAT fd7d85f6cf8c407f96dc83426f103350
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-ahlersandogletree-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH AhlersAndOgletree-UAT BetaTestUAT
  signAndUpload AhlersAndOgletree AhlersAndOgletree-UAT BetaTestUAT 82db485a90c8497fb9d8ed34125f20a7
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-capitolineauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH CapitolineAuctions-UAT BetaTestUAT
  signAndUpload CapitolineAuctions CapitolineAuctions-UAT BetaTestUAT dddd4d0f7bef465aa5f5c081dde37c2b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-dupuis-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: pavel zvertsov (AXU5VE4FBD)"
  $BUILD_BRANDS_SH Dupuis-UAT BetaTestUAT
  signAndUpload Dupuis Dupuis-UAT BetaTestUAT fe26133a7f37222f36835f9bcf9efa10
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-spectrumwine-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Spectrum Wine Auctions (46WU8364S4)"
  $BUILD_BRANDS_SH SpectrumWine-UAT BetaTestUAT
  signAndUpload SpectrumWine SpectrumWine-UAT BetaTestUAT 6a86f9982ef44ffbad2a3bf093b979d4
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-appletreeauctioncenter-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH AppleTreeAuctionCenter-UAT BetaTestUAT
  signAndUpload AppleTreeAuctionCenter AppleTreeAuctionCenter-UAT BetaTestUAT a8d4aa9067244a31bcd4b2bcdf9fc6d1
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-ritchasonauctioneers-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH RitchasonAuctioneers-UAT BetaTestUAT
  signAndUpload RitchasonAuctioneers RitchasonAuctioneers-UAT BetaTestUAT 8d869e0677dd4d229a05639249175715
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-trueblueauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH TrueBlueAuctions-UAT BetaTestUAT
  signAndUpload TrueBlueAuctions TrueBlueAuctions-UAT BetaTestUAT 320f2731c2d148158da4138fa88ab9c3
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-winslowauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH WinslowAuctions-UAT BetaTestUAT
  signAndUpload WinslowAuctions WinslowAuctions-UAT BetaTestUAT 08a6623f20084564a3058b5db031c2cb
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-bidglobal-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH BidGlobal-UAT BetaTestUAT
  signAndUpload BidGlobal BidGlobal-UAT BetaTestUAT 3c56ab8b11664f59b7b0a9a3c371d359
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-butterscotchauctioneers-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH ButterscotchAuctioneers-UAT BetaTestUAT
  signAndUpload ButterscotchAuctioneers ButterscotchAuctioneers-UAT BetaTestUAT 7274b0afd5ef4801af92b82c46443964
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-capitolcoinauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH CapitolCoinAuctions-UAT BetaTestUAT
  signAndUpload CapitolCoinAuctions CapitolCoinAuctions-UAT BetaTestUAT c295cf18b826450f89ac2706173a58b6
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-dafauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH DAFAuctions-UAT BetaTestUAT
  signAndUpload DAFAuctions DAFAuctions-UAT BetaTestUAT ce8bfe329b6c45e5b4eafa6161caf02a
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-novaartauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH NovaArtAuctions-UAT BetaTestUAT
  signAndUpload NovaArtAuctions NovaArtAuctions-UAT BetaTestUAT 7f23d3ddf4c74fcea217d2b617c22414
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-saksandwelkauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH SaksAndWelkAuctions-UAT BetaTestUAT
  signAndUpload SaksAndWelkAuctions SaksAndWelkAuctions-UAT BetaTestUAT 1ea4937f24434dadb950abd58ea38f3b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-cooperowen-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH CooperOwen-UAT BetaTestUAT
  signAndUpload CooperOwen CooperOwen-UAT BetaTestUAT 2a05e00b3d17492bb1ea20332656d00e
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-peachtreeandbennett-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH PeachtreeAndBennett-UAT BetaTestUAT
  signAndUpload PeachtreeAndBennett PeachtreeAndBennett-UAT BetaTestUAT 7761f56f10b04a669cc17590553ee4c7
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-racheldavisfinearts-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH RachelDavisFineArts-UAT BetaTestUAT
  signAndUpload RachelDavisFineArts RachelDavisFineArts-UAT BetaTestUAT c56d82c0356a4a43aae23288266e0874
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-crawfordfamilyauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH CrawfordFamilyAuctions-UAT BetaTestUAT
  signAndUpload CrawfordFamilyAuctions CrawfordFamilyAuctions-UAT BetaTestUAT 67ea930b95a94196a7883b9d7a2b5f8c
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-artelisted-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH Artelisted-UAT BetaTestUAT
  signAndUpload Artelisted Artelisted-UAT BetaTestUAT 9a09a667061c4960aaf16c948c2469f9
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-doranauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH DoranAuctions-UAT BetaTestUAT
  signAndUpload DoranAuctions DoranAuctions-UAT BetaTestUAT 38196f237af944e39bfb92be3e792f2b
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-kingsauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH KingsAuctions-UAT BetaTestUAT
  signAndUpload KingsAuctions KingsAuctions-UAT BetaTestUAT 7e107ac2c0b8410792ce46c4e9bdc164
fi
if [[ "$TRAVIS_BRANCH" == "z-deploy-liskaoregonauctions-uat" ]]; then
	DEVELOPER_NAME="iPhone Distribution: Auction Mobility LLC (SZLJXN98AP)"
  $BUILD_BRANDS_SH LiskaOregonAuctions-UAT BetaTestUAT
  signAndUpload LiskaOregonAuctions LiskaOregonAuctions-UAT BetaTestUAT a79c80f9400c4d529b0aa69496820841
fi
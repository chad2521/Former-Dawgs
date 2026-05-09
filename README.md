# Diamond Dawgs

A small SwiftUI iOS app for checking Konnor Griffin plus former Mississippi State baseball players.

## What it does

- Lets you switch between Konnor Griffin and former Mississippi State players.
- Shows each player's current MLB profile from MLB Stats API.
- Loads current season hitting or pitching stats depending on the player.
- Lists recent story links from a Google News RSS search for that player.
- Provides quick highlight links for MLB.com and YouTube.
- Follows the iPhone's system light/dark appearance automatically.

## Run it

Open `KonnorDaily.xcodeproj` in Xcode, choose an iPhone simulator or connected iPhone, then press Run.

If Xcode asks for signing, set your Apple development team under the `KonnorDaily` target.

## Notes

- The app uses public endpoints and does not require API keys.
- The roster focuses on former Bulldogs listed by Mississippi State's 2026 #StateToTheShow page whose MLB/MiLB player ids were verified.
- Google News RSS is a practical starter feed. For a polished App Store version, consider replacing it with licensed news/highlight providers or official MLB content feeds.
- This workspace only had Command Line Tools selected, so the project was not compiled locally with `xcodebuild`.

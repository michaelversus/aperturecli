# NSAssets CLI Board

## Backlog
- introduce lessons.md
- Generate assertions for the app using the configuration properties

# Current Sprint

## TODO
- remove debug command for Test post Actions

## In Progress


## Done
- init command under the user pwd wire things up
- init command request from user schemes to add post action scripts
- introduce sync schemes command
- use sync schemes command to add test post actions scripts that echo
- add lots of tests for every file
- introduce derivedDataLocator
- Implement xcresult parse command and initially use it just to find the proper xcresult files per xcsheme inside derived data.
- use spawn bg process for test post actions
- implement custom xcresult parsing
- make local spm packages directory optional
- empty selection for schemes should mean no test post actions setup
- create nsassets-artifacts directory to store data parsed
- post notification after every xcresult parse command finishes. Check if notification can pass the files the NSAssets Studio app needs to check.
- How we should manage recurring test executions? Keep artifacts for all? 
Maybe clean assets and keep only those of the last failure? We might want to clean up artifacts after every test execution.
- init command maybe should ask to edit gitignore for the user to exclude nsassets-artifacts

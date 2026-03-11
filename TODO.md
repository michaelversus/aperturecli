# Aperture CLI Board

## Backlog
- introduce lessons.md
- parse xcresult files
- create .aperture directory to store data parsed

# Current Sprint

## TODO
- introduce xcresultkit dependency or implement our own?
- revert post-action script to use `aperture` instead of `/Users/m.karagiorgos/aperturecli/.build/debug/ApertureCLI`
- make local spm packages directory optional

## In Progress
- Implement xcresult parse command and initially use it just to find the proper xcresult files per xcsheme inside derived data.

## Done
- init command under the user pwd wire things up
- init command request from user schemes to add post action scripts
- introduce sync schemes command
- use sync schemes command to add test post actions scripts that echo
- add lots of tests for every file
- introduce derivedDataLocator

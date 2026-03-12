# Aperture CLI Board

## Backlog
- introduce lessons.md
- parse xcresult files
- Generate assertions for the app using the configuration properties
- create .aperture directory to store data parsed

# Current Sprint

## TODO
- remove debug command for Test post Actions
- make local spm packages directory optional
- empty selection for schemes should mean no test post actions setup


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

# Time Rework

- [X] **WIP** improve the pause/loading handling for time stuff
- [ ] **WIP** fix saving issue where RMS remaining time is wrong

- [X] rename the variables to have descriptive names
- [X] remove `PendingTimerLoop`

# RMTS rework
- [ ] base on RMS instead of RMT
    - try to create a base for both RMT and RMTS (called `RMTBase) to avoid code duplication

# General
- [ ] create a proper base class `RMBase` as a parent class for all the modes 

# UI
- [ ] fix position issue of medal/skips numbers relative to images (seen in RMS, might affect RMC as well)
- [ ] fix position of "continue" button in the load map dialog so it isn't cut off



# Later Ideas
## Run Saving
- [ ] create seperate savefiles for the modes
- [ ] save the type of goal medal to avoid "converting" medals to a better tier when loading
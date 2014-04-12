--we're going to use this file to hold all the data about our sheets
--if you change the sheets, make sure to adjust the data here accordingly, without changing the name of the animations

local sheetsData = {};

sheetsData.loadGameSheetsData = function()

  local c_options =
{
    width = 127,
    height = 164,
    numFrames = 13,
    sheetContentWidth = 1043,  --width of original 1x size of entire sheet
    sheetContentHeight = 350  --height of original 1x size of entire sheet
}
local c_sheet = graphics.newImageSheet( "IMG/gameScene/run_001.png", c_options )
  local characterAnimations = {
    {name = "run", sheet = c_sheet, start = 11, count = 4, time = 400, loopCount = 0},
    {name = "die", sheet = c_sheet, start = 0, count = 4, time = 400, loopCount = 1},
    {name = "jump", sheet = c_sheet, frames = {5,6,8,9,10}, time = 400, loopCount = 1},
    {name = "fall", sheet = c_sheet, frames = {5,6}, time = 400, loopCount = 1},
  };
  local options = require ("IMG.gameScene.gameSheet").getSheetOptions();
  --change the below values to support dynamic resolution automatically
  --they must be the dimension of the image sheet at 1x
  local baseSheet = graphics.newImageSheet("IMG/gameScene/gameSheet.png", options);
  local coinsAnimations = {
    {name = "spin", sheet = baseSheet, start = 1, count = 6, time = 300, loopCount = 0}
  };
  
  local purpleEnemyAnimations = {
    {name = "normal", sheet = baseSheet, frames = {30, 31, 32, 31, 30, 33}, time = 500, loopCount = 0}
  };
  
  local blueEnemyAnimations = {
    {name = "normal", sheet = baseSheet, frames = {11, 12, 13, 12, 11, 14}, time = 500, loopCount = 0}
  };
  
  local yellowEnemyAnimations = {
    {name = "normal", sheet = baseSheet, frames = {45, 46, 47, 46, 45, 48}, time = 500, loopCount = 0}
  };

  return {characterSheet = c_sheet, sheet = baseSheet, characterAnim = characterAnimations, coinsAnim = coinsAnimations, purpleEnemyAnim = purpleEnemyAnimations, blueEnemyAnim = blueEnemyAnimations, yellowEnemyAnim = yellowEnemyAnimations};
end

return sheetsData;
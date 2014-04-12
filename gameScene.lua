----------------------------------------------------------------------------------
--
-- scenetemplate.lua
--
----------------------------------------------------------------------------------

local storyboard = require( "storyboard" )
local scene = storyboard.newScene()

--since we're keeping our entire code for the game scene well under 1000 lines (counting space and storyboard stuff)
--I've decided not to split it too much between modules.
--This helps for several reason (less needs of passing variables back and forth)
--but obviously if you're gonna add a ton of stuff in there, make sure that it never becomes unreadable or a mess to navigate through
--by properly splitting where possible (:

local physics = require "physics";

local ragdogLib = require "ragdogLib";
local fpsLib = require "fpsLib";
local adsLib = require "adsLib";

--here we hold our sounds
local jumpSFX;
local coinSFX;
local loseSFX;

--this loads our sheetsData table
local sheetsData = require "sheetsData";
--here we hold informations about the character 
local gameSheet;
local csheet;
local characterAnimations, coinsAnimations, purpleEnemyAnimations, blueEnemyAnimations, yellowEnemyAnimations;

--here we load our information about predefined spawns for platform
local platformsData = require "platformsSetup";
local currentSpawnTable;
local currentPositionInSpawnTable;
local currentSpawnedObject;
local spawnNewObject;
local spawnObjectsPool;

--we declare all our variables here
local createBackground; --this will hold our parallax background effect creation
local createPlatform; --this will hold our basic platform creation
local createCharacter; --and this our character creation
local createCoins; --this holds the coins creation
local createPurpleEnemy;--this holds one of our enemies;
local createBlueEnemy;
local createYellowEnemy;
local createHeart;
local createInvincibility;

--our groups
local backgroundLayer;
local gameLayer;
local hudLayer;
local character;

local createHudLayer;

--coins functions
local coinsPrepare;
local coinsDisappear;
local coinsEnterframe;

--powerup functions
local powerupPrepare;
local powerupDisappear;
local heartEnterframe;
local invincibilityEnterframe;

--enemies functions, we're gonna share some of them between our enemies
local enemiesPurplePrepare;
local enemiesPurpleDisappear;
local enemiesPurpleEnterframe;
local enemiesYellowPrepare;
local enemiesYellowDisappear;
local enemiesYellowEnterframe;
local enemiesBluePrepare;
local enemiesBlueDisappear;
local enemiesBlueEnterframe;

--collision filters. We specify here our filter bits of r enemies, players and ground
local enemyCatBit, enemyMaskBit = 4, 1; --we need the enemies to touch the ground, but also touch the player with an isSensor body, so we have 2 categories and masks for them
local enemy2CatBit, enemy2MaskBit = 8, 2;
local charCatBit, charMaskBit = 2, 9;
local groundCatBit, groundMaskBit = 1, 7;

--needed tables
local platformsPool;
local platformsEnterframe;
local platformPrepare;
local platformDisappear;
local currentPlatform;
local maxPlatformSizeX = 10; 
local minPlatformSizeX = 3; --min platform size can't be lower than 2
assert(minPlatformSizeX > 1, "Min Platform Size can't be lower than 2!");
local maxDistanceBetweenPlatformX = 200;
local minDistanceBetweenPlatformX = 60;
local distanceBetweenPlatformY = 90;

local backgroundSpeed = 2; --make sure to change these values in the exitScene page as well, if you plan to change them
local gameSpeed = 200;
local jumpPower = 200;
local maxJumpOffset = 90; --this is how many pixel can the character "jump" before the jump is deactivated

local currentScore, currentCoins;
local scoreIncreaseValue = 10/60; --the score will increase by this value every single frame. Make sure to change inside the createHudLayer function as well if you plan on changing it

local currentLifes;
local startingLifes = 3; --we reset all these values inside the createHudLayer function

--now for the powerups spawning
local heartFrequency = 15; --this means that whenever an heart should spawn, it'll have a 15% chance of actually being an heart, and a 85% of it being a simple coin;
local invincibilityFrequency = 15; --same as the heart, make sure to modify them inside the createScene event as well
local invincibilityTime = 5*60 --starts at 5 seconds. Make sure to change in in createScene;
 

--we localize the math functions here so their reading gets faster
local mRandom = math.random;
local mMin = math.min;
local mMax = math.max;
local mFloor = math.floor;
local mAbs = math.abs;

--We also need the data of our upgrades
local upgradesData = require "upgradesData";
local purchasesData; --we grab this in our createScene function

local loadGameOverScene;
local gameIsPaused;
local pauseGame;

loadGameOverScene = function()
  adsLib.removeBannerAd();
  physics.pause();
  backgroundSpeed = 0;
  gameSpeed = 0;
  scoreIncreaseValue = 0;
  _G.gameResults = {
    score = math.floor(currentScore),
    coins = currentCoins
  };
  storyboard.showOverlay("gameoverScene");
end

pauseGame = function()
  gameIsPaused = true;
  physics.pause();
  local iterateToPauseResume;
  iterateToPauseResume = function(group, pause)
		for i = group.numChildren, 1, -1 do
			if group[i].numChildren then
				iterateToPauseResume(group[i], pause);
			else
        if pause then
          if group[i].pause then
            group[i]:pause();
          end
        else
          if group[i].play then
            group[i]:play();
          end
        end
			end
		end
	end
  iterateToPauseResume(scene.view, true);
  storyboard.showOverlay("pauseScene");
  
  function scene.view:enterFrame()
    if not storyboard.getScene("pauseScene") then
      Runtime:removeEventListener("enterFrame", self);
      iterateToPauseResume(scene.view);
      physics.start();
      gameIsPaused = false;
    end
  end
  Runtime:addEventListener("enterFrame", scene.view);
end

createHudLayer = function(group)
  local originY = display.screenOriginY;
  if _G.providerForBannerAds ~= "none" then
    originY = originY+45;
  end
  currentScore, currentCoins = 0, 0;
  startingLifes = (upgradesData[1].levelsData[purchasesData["1"] or 1].value or 3);
  currentLifes = startingLifes;
  scoreIncreaseValue = (10/60)*(upgradesData[2].levelsData[purchasesData["2"] or 1].value or 1);

  local scoreImg = display.newImageRect(group, gameSheet, 9, 73, 17);
  scoreImg.x, scoreImg.y = display.screenOriginX+10+scoreImg.contentWidth*.5, originY+10+scoreImg.contentHeight*.5;
  local scoreText = display.newText(group, currentScore, 0, 0, native.systemFont, 20);
  scoreText:setTextColor(0, 0, 0);
  scoreText.x, scoreText.y = scoreImg.contentBounds.xMax+scoreText.contentWidth*.5+10, scoreImg.y;
  local scoreTextStartPositionX = scoreText.contentBounds.xMin; --we hold onto this so we don't have to recalculate it every time
  
  local pauseBut = display.newImageRect(group, gameSheet, 8, 22, 21);
  pauseBut.x, pauseBut.y = display.contentCenterX, scoreImg.y;
  function pauseBut:touch(event)
    if event.phase == "began" then
      display.getCurrentStage():setFocus(self);
    elseif event.phase == "ended" then
      audio.play(_G.clickSFX, {channel = audio.findFreeChannel()});
      display.getCurrentStage():setFocus(nil);
      pauseGame();
    end
    return true;
  end
  pauseBut:addEventListener("touch", pauseBut);
  
  local lifesTab = {};
  for i = 1, currentLifes do
    local life = display.newImageRect(group, "IMG/gameScene/Heart.png", 19, 16);
    life.x, life.y = display.contentWidth-(display.screenOriginX)-10-life.contentWidth*.5-(i-1)*life.contentWidth, scoreImg.y;
    lifesTab[i] = life;
  end
  lifesTab.currentLifes = currentLifes;
  
  function scoreText:enterFrame()
    if gameIsPaused then
      return;
    end
    currentScore = currentScore+scoreIncreaseValue;
    self.text = mFloor(currentScore);
    self.x = scoreTextStartPositionX+self.contentWidth*.5;
    --here we handle the life bar as well
    if currentLifes > lifesTab.currentLifes then
      lifesTab.currentLifes = lifesTab.currentLifes+1;
      local life = display.newImageRect(group, "IMG/gameScene/Heart.png", 19, 16);
      life.x, life.y = lifesTab[#lifesTab].x-life.contentWidth, scoreImg.y;
      lifesTab[#lifesTab+1] = life;
    elseif currentLifes < lifesTab.currentLifes then
      lifesTab.currentLifes = lifesTab.currentLifes-1;
      lifesTab[#lifesTab]:removeSelf();
      lifesTab[#lifesTab] = nil;
    end
  end
  Runtime:addEventListener("enterFrame", scoreText);
end

spawnNewObject = function(currPlatform)
  local spawnValue = (currentSpawnTable[currentPositionInSpawnTable] or 100);
  if spawnValue == 2 then --if it's for an heart, let's calculate the probability of it actually spawning
    local chance = mRandom(1, 100);
    if chance > heartFrequency then
      spawnValue = 1;
    end
  elseif spawnValue == 3 then
    local chance = mRandom(1, 100);
    if chance > invincibilityFrequency then --same as the heart
      spawnValue = 1;
    end
  end
  local tab = spawnObjectsPool[spawnValue] or {};
  local obj = tab[#tab];
  if not obj then
    if spawnValue == 1 then
      createCoins(gameLayer);
    elseif spawnValue == 2 then
      createHeart(gameLayer);
    elseif spawnValue == 3 then
      createInvincibility(gameLayer);
    elseif spawnValue == 4 then
      createYellowEnemy(gameLayer);
    elseif spawnValue == 5 then
      createPurpleEnemy(gameLayer);
    elseif spawnValue == 6 then
      createBlueEnemy(gameLayer);
    end
    obj = tab[#tab];
  end
  if obj then
    local currentPlatform = currPlatform or currentPlatform;
    obj.platform = currentPlatform;
    tab[#tab] = nil;
    currentPositionInSpawnTable = currentPositionInSpawnTable+1;
    local x = currentPlatform.x-currentPlatform.width*.5+currentSpawnTable[currentPositionInSpawnTable];
    currentPositionInSpawnTable = currentPositionInSpawnTable+1;
    local y = currentPlatform.y-currentPlatform.height*.5+currentSpawnTable[currentPositionInSpawnTable];
    currentPositionInSpawnTable = currentPositionInSpawnTable+1;
    obj:prepare(x, y);
    currentSpawnedObject = obj;
  end
end

powerupPrepare = function(self, x, y)
  self.isBodyActive = true;
  self.x, self.y = x, y;
  self.platform = nil;
end

powerupDisappear = function(self)
  self.isBodyActive = false;
  self.y = -1000;
  self.hasTouchedCharacter = nil;
  spawnObjectsPool[self.numericId][#spawnObjectsPool[self.numericId]+1] = self;
end

heartEnterframe = function(self)
  local platContentXleft, platContentYtop = self.parent:localToContent(self.x+self.width*.5, self.y-self.height*.5); 
  if self.hasTouchedCharacter or platContentXleft < display.screenOriginX-20 then
    if self.hasTouchedCharacter then
    --  audio.play(coinSFX, { channel = audio.findFreeChannel });
      if  currentLifes < startingLifes then
        currentLifes = currentLifes+1;
      end
    end
    Runtime:removeEventListener("enterFrame", self);
    self:disappear();
  end
end

invincibilityEnterframe = function(self)
  local platContentXleft, platContentYtop = self.parent:localToContent(self.x+self.width*.5, self.y-self.height*.5); 
  if self.hasTouchedCharacter or platContentXleft < display.screenOriginX-20 then
    Runtime:removeEventListener("enterFrame", self);
    self:disappear();
  end
end

createHeart = function(group)
  spawnObjectsPool = spawnObjectsPool or {};
  spawnObjectsPool[2] = spawnObjectsPool[2] or {};
  
  local heart = display.newImageRect(gameLayer, gameSheet, 15, 20, 20);
  heart.id = "heart";
  heart.numericId = 2;
  
  physics.addBody(heart, "static", {isSensor = true, bounce = 0, friction = 0, density = 0, radius = heart.contentWidth*.5});
  
  heart.prepare = powerupPrepare;
  heart.disappear = powerupDisappear;
  heart.enterFrame = heartEnterframe;
  
  heart:disappear();
end

createInvincibility = function(group)
  spawnObjectsPool = spawnObjectsPool or {};
  spawnObjectsPool[3] = spawnObjectsPool[3] or {};
  
  local invincibile = display.newImageRect(gameLayer, gameSheet, 44, 20, 20);
  invincibile.id = "invincibility";
  invincibile.numericId = 3;
  
  physics.addBody(invincibile, "static", {isSensor = true, bounce = 0, friction = 0, density = 0, radius = invincibile.contentWidth*.5});
  
  invincibile.prepare = powerupPrepare;
  invincibile.disappear = powerupDisappear;
  invincibile.enterFrame = invincibilityEnterframe;
  
  invincibile:disappear();
end

enemiesPurplePrepare = function(self, x, y)
  self.isBodyActive = true;
  self.x, self.y = x, y;
  self.time = mRandom(0, 100);
  self:play();
end

enemiesPurpleDisappear = function(self)
  self:setLinearVelocity(0, 0);
  self:setSequence("spin");
  self:pause();
  self.platform = nil;
  self.isBodyActive = false;
  self.y = -1000;
  self.hasTouchedCharacter = nil;
  self.time = 0;
  spawnObjectsPool[self.numericId][#spawnObjectsPool[self.numericId]+1] = self;
end

enemiesPurpleEnterframe = function(self)
  local platContentXleft, platContentYtop = self.parent:localToContent(self.x+self.width*.5, self.y-self.height*.5); 
  if platContentXleft < display.screenOriginX-30 then
    Runtime:removeEventListener("enterFrame", self);
    self:disappear();
    return;
  end
  self.time = self.time+1*fpsLib.FPS;
  if self.time >= self.jumpTime then
    self.time = 0;
    self:setLinearVelocity(0, self.jumpForce);
  end
  --let's make the purple enemy jump every x seconds
end

createPurpleEnemy = function(group)
  spawnObjectsPool = spawnObjectsPool or {};
  spawnObjectsPool[5] = spawnObjectsPool[5] or {}; --this 5 here is the same id we can find in platformsSetup
  
  local enemy = display.newSprite(gameLayer, gameSheet, purpleEnemyAnimations);
  enemy.id = "enemy";
  enemy.name = "purpleEnemy"; --we use a name, in case we'd like to do something specific with a certain kind of enemy on collision
  enemy.damage = 1; --this is the amount of damage the enemy will make to the character
  enemy.numericId = 5; --this is the id that we setup on platformsSetup. By using a 5 in our platform construction, this enemy will pop up 
  enemy.time = 0; --a bit of convenient variable to make an enterframe timer
  enemy.jumpTime = 100; --here we specify how many frames should pass before the enemy jumps;
  enemy.jumpForce = -300; --and here the force of the enemy jump;
  
  physics.addBody(enemy, "dynamic", {bounce = 0, friction = 0, density = 1, filter = {categoryBits = enemyCatBit, maskBits = enemyMaskBit}},
    {isSensor = true, bounce = 0, friction = 0, density = 1, filter = {categoryBits = enemy2CatBit, maskBits = enemy2MaskBit}});  --enemies have two bodies, one is a sensor that will interact with the player, the other is not a sensor and interacts with the ground only);
  
  enemy.prepare = enemiesPurplePrepare;
  enemy.disappear = enemiesPurpleDisappear;
  enemy.enterFrame = enemiesPurpleEnterframe;
  enemy.isFixedRotation = true;
  
  enemy:disappear();
end

enemiesBluePrepare = function(self, x, y)
  self.isBodyActive = true;
  self.x, self.y = x, y;
  self.xScale = -1;
  self.directionSpeed = mAbs(self.directionSpeed);
  self:setLinearVelocity(self.directionSpeed, 0);
  self:play();
end

enemiesBlueDisappear = function(self)
  self:setLinearVelocity(0, 0);
  self:setSequence("spin");
  self:pause();
  self.platform = nil;
  self.isBodyActive = false;
  self.y = -1000;
  self.hasTouchedCharacter = nil;
  self.time = 0;
  spawnObjectsPool[self.numericId][#spawnObjectsPool[self.numericId]+1] = self;
end

enemiesBlueEnterframe = function(self)
  local platContentXleft, platContentYtop = self.parent:localToContent(self.x+self.width*.5, self.y-self.height*.5); 
  if platContentXleft < display.screenOriginX-30 then
    Runtime:removeEventListener("enterFrame", self);
    self:disappear();
    return;
  end
  if (self.contentBounds.xMin <= self.platform.frontGround.contentBounds.xMin and self.directionSpeed <= 0) or (self.contentBounds.xMax >= self.platform.backGround.contentBounds.xMax and self.directionSpeed >= 0) then
    self.directionSpeed = -self.directionSpeed;
    self:setLinearVelocity(self.directionSpeed, 0);
    if self.directionSpeed < 0 then
      self.xScale = 1;
    else
      self.xScale = -1;
    end
  end
  --let's make the blue enemy move to the left and back if he reaches part of the pit.
end

createBlueEnemy = function(group)
  spawnObjectsPool = spawnObjectsPool or {};
  spawnObjectsPool[6] = spawnObjectsPool[6] or {}; --this 6 here is the same id we can find in platformsSetup
  
  local enemy = display.newSprite(gameLayer, gameSheet, blueEnemyAnimations);
  enemy.id = "enemy";
  enemy.name = "blueEnemy"; --we use a name, in case we'd like to do something specific with a certain kind of enemy on collision
  enemy.damage = 1; --this is the amount of damage the enemy will make to the character
  enemy.numericId = 6; --this is the id that we setup on platformsSetup. By using a 6 in our platform construction, this enemy will pop up 
  enemy.directionSpeed = 60; --and here the speed of the enemy
  
  physics.addBody(enemy, "dynamic", {bounce = 0, friction = 0, density = 1, filter = {categoryBits = enemyCatBit, maskBits = enemyMaskBit}},
    {isSensor = true, bounce = 0, friction = 0, density = 1, filter = {categoryBits = enemy2CatBit, maskBits = enemy2MaskBit}});  --enemies have two bodies, one is a sensor that will interact with the player, the other is not a sensor and interacts with the ground only);
  
  enemy.prepare = enemiesBluePrepare;
  enemy.disappear = enemiesBlueDisappear;
  enemy.enterFrame = enemiesBlueEnterframe;
  enemy.isFixedRotation = true;
  
  enemy:disappear();
end

enemiesYellowPrepare = function(self, x, y)
  self.isBodyActive = true;
  self.x, self.y = x, y;
  self.xScale = 1;
  self.directionSpeed = -mAbs(self.directionSpeed);
  self:setLinearVelocity(self.directionSpeed, 0);
  self:play();
end

enemiesYellowDisappear = function(self)
  self:setLinearVelocity(0, 0);
  self:setSequence("spin");
  self:pause();
  self.platform = nil;
  self.isBodyActive = false;
  self.y = -1000;
  self.hasTouchedCharacter = nil;
  self.time = 0;
  spawnObjectsPool[self.numericId][#spawnObjectsPool[self.numericId]+1] = self;
end

enemiesYellowEnterframe = function(self)
  local platContentXleft, platContentYtop = self.parent:localToContent(self.x+self.width*.5, self.y-self.height*.5); 
  if platContentXleft < display.screenOriginX-30 then
    Runtime:removeEventListener("enterFrame", self);
    self:disappear();
    return;
  end
  if (self.contentBounds.xMin <= self.platform.frontGround.contentBounds.xMin and self.directionSpeed <= 0) or (self.contentBounds.xMax >= self.platform.backGround.contentBounds.xMax and self.directionSpeed >= 0) then
    self.directionSpeed = -self.directionSpeed;
    self:setLinearVelocity(self.directionSpeed, 0);
    if self.directionSpeed < 0 then
      self.xScale = 1;
    else
      self.xScale = -1;
    end
  end
  --let's make the yellow enemy move to the left and back if he reaches part of the pit, starting opposite of the blue one.
end

createYellowEnemy = function(group)
  spawnObjectsPool = spawnObjectsPool or {};
  spawnObjectsPool[4] = spawnObjectsPool[4] or {}; --this 6 here is the same id we can find in platformsSetup
  
  local enemy = display.newSprite(gameLayer, gameSheet, yellowEnemyAnimations);
  enemy.id = "enemy";
  enemy.name = "yellowEnemy"; --we use a name, in case we'd like to do something specific with a certain kind of enemy on collision
  enemy.damage = 1; --this is the amount of damage the enemy will make to the character
  enemy.numericId = 4; --this is the id that we setup on platformsSetup. By using a 6 in our platform construction, this enemy will pop up 
  enemy.directionSpeed = -60; --and here the speed of the enemy
  
  physics.addBody(enemy, "dynamic", {bounce = 0, friction = 0, density = 1, filter = {categoryBits = enemyCatBit, maskBits = enemyMaskBit}},
    {isSensor = true, bounce = 0, friction = 0, density = 1, filter = {categoryBits = enemy2CatBit, maskBits = enemy2MaskBit}});  --enemies have two bodies, one is a sensor that will interact with the player, the other is not a sensor and interacts with the ground only);
  
  enemy.prepare = enemiesYellowPrepare;
  enemy.disappear = enemiesYellowDisappear;
  enemy.enterFrame = enemiesYellowEnterframe;
  enemy.isFixedRotation = true;
  
  enemy:disappear();
end

coinsPrepare = function(self, x, y)
  self.isBodyActive = true;
  self.x, self.y = x, y;
  self.platform = nil;
  self:play();
end

coinsDisappear = function(self)
  self:setSequence("spin");
  self:pause();
  self.isBodyActive = false;
  self.y = -1000;
  self.hasTouchedCharacter = nil;
  spawnObjectsPool[1][#spawnObjectsPool[1]+1] = self;
end

coinsEnterframe = function(self)
  local platContentXleft, platContentYtop = self.parent:localToContent(self.x+self.width*.5, self.y-self.height*.5); 
  if self.hasTouchedCharacter or platContentXleft < display.screenOriginX-20 then
    if self.hasTouchedCharacter then
      audio.play(coinSFX, { channel = audio.findFreeChannel });
      currentScore = currentScore+scoreIncreaseValue;
      currentCoins = currentCoins+1;
    end
    Runtime:removeEventListener("enterFrame", self);
    self:disappear();
  end
end

createCoins = function(group)
  spawnObjectsPool = spawnObjectsPool or {};
  spawnObjectsPool[1] = spawnObjectsPool[1] or {};
  
  local coin = display.newSprite(gameLayer, gameSheet, coinsAnimations);
  coin.id = "coin";
  
  physics.addBody(coin, "static", {isSensor = true, bounce = 0, friction = 0, density = 0, radius = 3});
  
  coin.prepare = coinsPrepare;
  coin.disappear = coinsDisappear;
  coin.enterFrame = coinsEnterframe;
  
  coin:disappear();
end

createCharacter = function(group)
  character = display.newSprite(gameLayer, c_sheet, characterAnimations);
  character.x, character.y = 200, 140;
  physics.addBody(character, {bounce = 0, density = 1, friction = 0, filter = {categoryBits = charCatBit, maskBits = charMaskBit}});
  character:setLinearVelocity(gameSpeed, 0);
  character.isFixedRotation = true;
  character:setSequence("run");
  character:play();
  character.isDamaged = 0;
  
  local deathPitY = display.contentHeight-(display.screenOriginY*2);
  
  function character:enterFrame()
    local x, y = self.x, self.y;
    local xSpeed, ySpeed = self:getLinearVelocity();
    if self.activateJump then
      xSpeed = gameSpeed;
      ySpeed = -jumpPower;
      self:setLinearVelocity(xSpeed, ySpeed);
      if self.y <= self.maxJump then
        self.activateJump = nil;
      end
    elseif ySpeed < 0 then
      ySpeed = ySpeed*0.98;
      self:setLinearVelocity(xSpeed, ySpeed);
    elseif ySpeed > 0.2 then
      if self.sequence ~= "fall" then
        self:setSequence("fall");
        self:play();
      end
    else
      if self.sequence ~= "run" then
        self:setSequence("run");
        self:play();
      end
    end
    if self.isDamaged > 0 then
      self.isDamaged = self.isDamaged-1;
      self.alpha = math.sin(self.isDamaged*.5);
    else
      self.alpha = 1;
    end
    if y > deathPitY+50 or currentLifes <= 0 then  
      self:setSequence("die");
      self:play()
      Runtime:removeEventListener("enterFrame", character);
      loadGameOverScene();
    end
  end
  Runtime:addEventListener("enterFrame", character);
  
  function character:collision(event)
    if event.phase == "began" then
      if event.other.id == "block" then
        if self.contentBounds.yMax <= event.other.contentBounds.yMin then
          self.isJumpPossible = true;
          if self.sequence ~= "run" then
            self:setSequence("run");
            self:play();
          end
        end
      elseif event.other.id == "coin" then
        event.other.hasTouchedCharacter = true;
      elseif event.other.id == "heart" then
        event.other.hasTouchedCharacter = true;
      elseif event.other.id == "invincibility" then
        event.other.hasTouchedCharacter = true;
        self.isDamaged = invincibilityTime;
      elseif event.other.id == "enemy" then
        if (self.contentBounds.yMax) <= (event.other.contentBounds.yMin+6) then
          if event.other.name == "purpleEnemy" then
            event.other:setLinearVelocity(0, 200);
          end
          if self.isJumpPressed then
            audio.play(jumpSFX, { channel = audio.findFreeChannel });
            self:setLinearVelocity(gameSpeed, -jumpPower);
            self.activateJump = true;
            self.maxJump = character.y-maxJumpOffset;
            self:setSequence("jump");
            self:play();
            self.isJumpPressed = true;
          else
            self:setLinearVelocity(gameSpeed, -jumpPower);
          end
        else
          if self.isDamaged <= 0 then
            currentLifes = mMax(0, currentLifes-event.other.damage);
            self.isDamaged = 120;
          end
        end
      end
    elseif event.phase == "ended" then
      if event.other.id == "block" then
        self.isJumpPossible = nil;
      end
    end
  end
  character:addEventListener("collision", character);
  
  local background = backgroundLayer[1];
  function background:touch(event) --we put the touch on our biggest object, the background that covers the whole screen
    if event.phase == "began" then
      if character.isJumpPossible then
        audio.play(jumpSFX, { channel = audio.findFreeChannel });
        display.getCurrentStage():setFocus(self);
        character:setLinearVelocity(gameSpeed, -jumpPower);
        character.activateJump = true;
        character.maxJump = character.y-maxJumpOffset;
        self.isFocus = true;
        character:setSequence("jump");
        character:play();
        character.isJumpPressed = true;
      else
        character.isJumpPressed = true;
      end
    elseif event.phase == "ended" and self.isFocus then
      display.getCurrentStage():setFocus(nil);
      character.activateJump = nil;
      character.isJumpPressed = nil;
    end
  end
  background:addEventListener("touch", background);
end

platformsEnterframe = function(self, event)
  local platContentXleft, platContentYtop = self.parent:localToContent(self.backGround.x+self.backGround.width*.5, self.y-self.height*.5); 

  if platContentXleft < display.screenOriginX-20 then
    Runtime:removeEventListener("enterFrame", self);
    self:disappear();
  end
end

platformPrepare = function(self, sizeWidth, x, y) 
  --the size will be calculated based on the first width and first height.
  --this means that to a sizeWidth of 5, will correspond a width of 32*5;
  print(x, y);
  y = y+self.contentHeight*.5;
  self.frontGround.isVisible = true;
  self.frontGround.x, self.frontGround.y = x+self.frontGround.contentWidth*.5, y;
  self.frontGround.x, self.frontGround.y = x+self.frontGround.contentWidth*.5, y;
  local lastBlock = self.frontGround;
  for i = 1, sizeWidth-2 do
    self.middleGround[i].isVisible = true;
    self.middleGround[i].x, self.middleGround[i].y = lastBlock.x+lastBlock.contentWidth*.5+self.middleGround[i].contentWidth*.5, y;
    lastBlock = self.middleGround[i];
  end
  self.backGround.isVisible = true;
  self.backGround.x, self.backGround.y = lastBlock.x+lastBlock.contentWidth*.5+self.backGround.contentWidth*.5, y;
  
  physics.addBody(self, "static", {shape = {-self.contentWidth*.5, -self.contentHeight*.5, sizeWidth*self.contentWidth-self.contentWidth*.5, -self.contentHeight*.5, sizeWidth*self.contentWidth-self.contentWidth*.5, self.contentHeight*.5, -self.contentWidth*.5, self.contentHeight*.5}});
end

platformDisappear = function(self, event)
  physics.removeBody(self);
  self.frontGround.y = -1000;
  self.frontGround.isVisible = false;
  self.backGround.y = -1000;
  self.backGround.isVisible = false;
  for i = 1, #self.middleGround do
    self.middleGround[i].isVisible = false;
    self.middleGround[i].y = -1000;
  end
  platformsPool[#platformsPool+1] = self;
end

createPlatform = function(group, fullSize)
  --We're gonna user other 2.0 features for a pretty flexible platform creations.
  --Our platforms will consist of 4 objects. 3 for the grass at the top, and 1 for the ground.
  --To keep performance higher and help us with the physics bodies, we're gonna leave everything separated (not in a specific group, apart from their layer one).
  
  local frontGround = display.newImageRect(group, "IMG/gameScene/ground1.png", 32, 256);
  frontGround.isVisible = false;
  
  local backGround = display.newImageRect(group, "IMG/gameScene/ground3.png", 32, 256);
  backGround.isVisible = false;
  
  local middleGround = {};
  for i = 1, fullSize or maxPlatformSizeX-2 do
    local middleGroundBlock = display.newImageRect(group, "IMG/gameScene/ground2.png", 32, 256);
    middleGroundBlock.isVisible = false;
    middleGround[i] = middleGroundBlock;
  end


  frontGround.frontGround = frontGround;
  frontGround.backGround = backGround;
  frontGround.middleGround = middleGround;
  frontGround.enterFrame = platformsEnterframe;
  
  frontGround.id = "block";
  
  
  frontGround.preparePlatform = platformPrepare;
  frontGround.disappear = platformDisappear;

  --we will get some warnings because disappear pass the object to removeBody, and at this point it doesn't yet have a body.
  --don't bother about the warnings, I just didn't like to write 2 times the same code d:
  frontGround:disappear()
end

createBackground = function(group)
  --this is the first layer of the entire screen, the sky
  local layer1 = display.newImageRect(group, "IMG/gameScene/BG.png", display.contentWidth-(display.screenOriginX*2), display.contentHeight-(display.screenOriginY*2));  
  layer1.x, layer1.y = display.contentCenterX, display.contentCenterY;
  
  local backgroundLayer = _G.createParallaxBackground(group);
  
  --here we move each fill so that it'll look like the background is moving. The textureWrapX effect will make it so that every layer will look endless.
  function layer1:enterFrame()
    local FPS = fpsLib.FPS;
    if gameIsPaused then
      return;
    end
    backgroundLayer:update(backgroundSpeed);
  end
  Runtime:addEventListener("enterFrame", layer1);
end

-- Called when the scene's view does not exist:
function scene:createScene( event )
  adsLib.showBannerAd("top");
  --here we load our sounds too
  jumpSFX = audio.loadSound("SFX/jump.wav");
  coinSFX = audio.loadSound("SFX/coin.wav");
  loseSFX = audio.loadSound("SFX/lose2.wav");
  
  purchasesData = ragdogLib.getSaveValue("shop") or {};
  
  local sheetsAnimData = sheetsData.loadGameSheetsData();
  gameSheet = sheetsAnimData.sheet;
  charSheet = sheetsAnimData.c_sheet;
  characterAnimations = sheetsAnimData.characterAnim;
  coinsAnimations = sheetsAnimData.coinsAnim;
  purpleEnemyAnimations = sheetsAnimData.purpleEnemyAnim;
  blueEnemyAnimations = sheetsAnimData.blueEnemyAnim;
  yellowEnemyAnimations = sheetsAnimData.yellowEnemyAnim;
  
  heartFrequency = 15+(upgradesData[4].levelsData[purchasesData["4"] or 1].value or 0);
  invincibilityTime = (5+(upgradesData[3].levelsData[purchasesData["3"] or 1].value or 0))*60;

	local group = scene.view;
  backgroundLayer = display.newGroup();
  group:insert(backgroundLayer);
  createBackground(backgroundLayer);
  
  physics.start();
  physics.setGravity(0, 15);
  
  platformsPool = {};
  
  gameLayer = display.newGroup();
  group:insert(gameLayer);
  --let's prepare some platforms
  for i = 1, 5 do
    if i < 5 then
      createPlatform(gameLayer);
    else
      createPlatform(gameLayer, 48);
    end
  end
  
  for i = 1, 60 do
    createCoins(gameLayer);
  end
  
  for i = 1, 5 do
    createPurpleEnemy(gameLayer);
    createBlueEnemy(gameLayer);
    createYellowEnemy(gameLayer);
  end
  
  for i = 1, 3 do
    createHeart(gameLayer);
    createInvincibility(gameLayer);
  end
  
  --let's put the first platform in, pretty long so that it gives the player some time to prepare
  currentPlatform = platformsPool[#platformsPool];
  currentPlatform:preparePlatform(50, display.screenOriginX, 240);
  platformsPool[#platformsPool] = nil;
  
  createCharacter(gameLayer);
    
  hudLayer = display.newGroup();
  group:insert(hudLayer);
  createHudLayer(hudLayer);
  
  function gameLayer:enterFrame()
    self.x = -character.x+60;
    
    physics.setTimeStep(fpsLib.desiredFPS*fpsLib.FPS);
    
    local currPlatContentXleft, currPlatContentYtop = self:localToContent(currentPlatform.backGround.x+currentPlatform.backGround.width*.5, currentPlatform.y-currentPlatform.height*.5);
    if currentPlatform and currPlatContentXleft < display.contentWidth-(display.screenOriginX*2) then
      local platWidthSize = mRandom(minPlatformSizeX, maxPlatformSizeX);
      platformsPool[#platformsPool]:preparePlatform(platWidthSize, currentPlatform.backGround.x+currentPlatform.backGround.width*.5+mRandom(minDistanceBetweenPlatformX, maxDistanceBetweenPlatformX), mMin(240, mMax(150, currentPlatform.y-currentPlatform.height*.5+mRandom(-distanceBetweenPlatformY, distanceBetweenPlatformY))));
      Runtime:addEventListener("enterFrame", currentPlatform);
      currentPlatform = platformsPool[#platformsPool];
      currentPlatform.totalWidth = platWidthSize*currentPlatform.contentWidth;
      platformsPool[#platformsPool] = nil;
      currentSpawnTable = platformsData[platWidthSize][mRandom(1, #platformsData[platWidthSize])];
      currentPositionInSpawnTable = 1;
      spawnNewObject(currentPlatform);
    end
    
    if currentSpawnedObject then
      local currSpawnContentXleft, currSpawnContentYtop = self:localToContent(currentSpawnedObject.x-currentPlatform.totalWidth*.5, currentSpawnedObject.y);
      if currSpawnContentXleft < display.contentWidth-(display.screenOriginX*2) then
        Runtime:addEventListener("enterFrame", currentSpawnedObject);
        local savedPlatform = currentSpawnedObject.platform;
        currentSpawnedObject = nil;
        spawnNewObject(savedPlatform);
      end
    end
  end
  Runtime:addEventListener("enterFrame", gameLayer);
  
  sheetsData.loadGameSheetsData();
end

-- Called immediately after scene has moved onscreen:
function scene:enterScene( event )
	local group = self.view
end


-- Called when scene is about to move offscreen:
function scene:exitScene( event )
  --let's dispose of the sounds
  spawnObjectsPool = nil;
  audio.dispose(jumpSFX);
  audio.dispose(loseSFX);
  audio.dispose(coinSFX);
  jumpSFX = nil;
  loseSFX = nil;
  coinSFX = nil;
  currentSpawnedObject = nil;
  currentPlatform = nil;
  backgroundSpeed = 3; 
  gameSpeed = 200;
  gameIsPaused = nil;
  
	local group = self.view
  
  platformsPool = nil;
	
	local removeAll;
	
	removeAll = function(group)
		if group.enterFrame then
			Runtime:removeEventListener("enterFrame", group);
		end
		if group.touch then
			group:removeEventListener("touch", group);
			Runtime:removeEventListener("touch", group);
		end		
		for i = group.numChildren, 1, -1 do
			if group[i].numChildren then
				removeAll(group[i]);
			else
				if group[i].enterFrame then
					Runtime:removeEventListener("enterFrame", group[i]);
				end
				if group[i].touch then
					group[i]:removeEventListener("touch", group[i]);
					Runtime:removeEventListener("touch", group[i]);
				end
			end
		end
	end
  
  if group then
    removeAll(group);
  end
	-----------------------------------------------------------------------------
	
	--	INSERT code here (e.g. stop timers, remove listeners, unload sounds, etc.)
	
	-----------------------------------------------------------------------------
	
end


-- Called prior to the removal of scene's "view" (display group)
function scene:destroyScene( event )
	local group = self.view
	
	-----------------------------------------------------------------------------
	
	--	INSERT code here (e.g. remove listeners, widgets, save state, etc.)
	
	-----------------------------------------------------------------------------
	
end


---------------------------------------------------------------------------------
-- END OF YOUR IMPLEMENTATION
---------------------------------------------------------------------------------

-- "createScene" event is dispatched if scene's view does not exist
scene:addEventListener( "createScene", scene )

-- "enterScene" event is dispatched whenever scene transition has finished
scene:addEventListener( "enterScene", scene )

-- "exitScene" event is dispatched before next scene's transition begins
scene:addEventListener( "exitScene", scene )

-- "destroyScene" event is dispatched before view is unloaded, which can be
-- automatically unloaded in low memory situations, or explicitly via a call to
-- storyboard.purgeScene() or storyboard.removeScene().
scene:addEventListener( "destroyScene", scene )

---------------------------------------------------------------------------------



return scene
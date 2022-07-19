--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

KEY_SPAWN_TIMER = 8 -- x seconds before an spawn

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball = {params.ball}
    self.level = params.level
    
    self.powerup = false
    self.keyTimer = 0
    self.key = false
    self.hasKey = false
    self.recoverPoints = 5000
    
    self.hasLock = false
    for k, brick in pairs(self.bricks) do
        if brick.locked then
            self.hasLock = true
            break
        end
    end

    -- give ball random starting velocity
    self.ball[1].dx = math.random(-200, 200)
    self.ball[1].dy = math.random(-50, -60)
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    if self.powerup then
        self.powerup:update(dt)
    end
    if self.key then
        self.key:update(dt)
    end

    -- NEW LOOP START!
    for i = #self.ball, 1, -1 do
        self.ball[i]:update(dt)

        if self.ball[i]:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            self.ball[i].y = self.paddle.y - 8
            self.ball[i].dy = -self.ball[i].dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if self.ball[i].x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                self.ball[i].dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - self.ball[i].x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif self.ball[i].x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                self.ball[i].dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - self.ball[i].x))
            end

            gSounds['paddle-hit']:play()
        end
    end
    -- NEW LOOP END!

    -- Spawns a key if needed
    if self.hasLock and not self.hasKey and self.keyTimer > KEY_SPAWN_TIMER then
        self.key = Powerup(math.random(0, VIRTUAL_WIDTH - 16), 0, 144)
        self.keyTimer = 0
    else
        self.keyTimer = self.keyTimer + dt
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do
        
        -- NEW LOOP START!
        for i = #self.ball, 1, -1 do
            -- only check collision if we're in play
            if brick.inPlay and self.ball[i]:collides(brick) then
                if not brick.locked then
                    -- check if spawn powerup
                    if not self.powerup and table.getn(self.ball) <= 1 and 1 == math.random(1, 6) then
                        self.powerup = Powerup(self.ball[i].x, self.ball[i].y, 96)
                    end
                    
                    -- add to score
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()
                
                elseif self.hasKey then
                    -- unlock block
                    brick.locked = false

                    --add to score for unlocking brick
                    self.score = self.score + 1200
                end

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)
                    
                    -- increase paddle size
                    if self.paddle.size < 4 then
                        self.paddle.size = self.paddle.size + 1
                        self.paddle.width = self.paddle.size * 32
                    end

                    -- multiply recover points by 2
                    self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)
                    
                    -- play recover sound effect
                    gSounds['recover']:play()
                end
                
                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()
                    
                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = self.ball[i],
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --
                
                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if self.ball[i].x + 2 < brick.x and self.ball[i].dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    self.ball[i].dx = -self.ball[i].dx
                    self.ball[i].x = brick.x - 8
                    
                    -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                    -- so that flush corner hits register as Y flips, not X flips
                elseif self.ball[i].x + 6 > brick.x + brick.width and self.ball[i].dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    self.ball[i].dx = -self.ball[i].dx
                    self.ball[i].x = brick.x + 32
                    
                    -- top edge if no X collisions, always check
                elseif self.ball[i].y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    self.ball[i].dy = -self.ball[i].dy
                    self.ball[i].y = brick.y - 8
                    
                    -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    self.ball[i].dy = -self.ball[i].dy
                    self.ball[i].y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(self.ball[i].dy) < 150 then
                    self.ball[i].dy = self.ball[i].dy * 1.02
                end
                
                -- only allow colliding with one brick, for corners
                break
            end
        end
        -- NEW LOOP END!
    end

    if self.key then
        if self.key:collides(self.paddle) then
            self.hasKey = true
            self.key = false
        elseif self.key.y >= VIRTUAL_HEIGHT then
            self.key = false
        end
    end
    
    if self.powerup then
        if self.powerup:collides(self.paddle) then
            newBall1 = Ball()
            
            newBall2 = Ball()
            newBall1.skin = math.random(7)
            newBall2.skin = math.random(7)
            newBall1.x = self.powerup.x
            newBall2.x = self.powerup.x
            newBall1.y = self.powerup.y - 5
            newBall2.y = self.powerup.y - 5
            newBall1.dx = math.random(-200, 200)
            newBall2.dx = math.random(-200, 200)
            newBall1.dy = math.random(-50, -60)
            newBall2.dy = math.random(-50, -60)
            table.insert(self.ball, newBall1)
            table.insert(self.ball, newBall2)
            self.powerup = false
        elseif self.powerup.y >= VIRTUAL_HEIGHT then
            self.powerup = false
        end
    end

    -- NEW STUFF HERE!
    -- if ball dies remove from list, then if no balls left subtract from health and whatever else
    for i = #self.ball, 1, -1 do
        -- if ball goes below bounds, revert to serve state and decrease health
        if self.ball[i].y >= VIRTUAL_HEIGHT then
            -- remove ball that went out of bounds
            table.remove(self.ball, i)
            
            if #self.ball < 1 then
                self.health = self.health - 1

                -- decrease size by one if possible
                if self.paddle.size > 1 then
                    self.paddle.size = self.paddle.size - 1
                    self.paddle.width = self.paddle.size * 32
                end

                gSounds['hurt']:play()
            end
            
            if self.health == 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            elseif #self.ball < 1 then
                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints
                })
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render powerups if there
    if self.powerup then
        self.powerup:render()
    end

    -- render key is there
    if self.key then
        self.key:render()
    end

    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    -- NEW LOOP START!
    for i = #self.ball, 1, -1 do
        self.ball[i]:render()
    end
    -- NEW LOOP END!

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end
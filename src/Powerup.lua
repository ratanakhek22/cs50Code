

Powerup = Class{}

FALLSPEED = 35

function Powerup:init(x, y, qx)
    self.width = 16
    self.height = 16
    self.quadx = qx

    self.x = x
    self.y = y
    self.dy = FALLSPEED
end

function Powerup:update(dt)
    self.y = self.y + self.dy * dt
end

function Powerup:collides(paddle)
    if self.x > paddle.x + paddle.width or paddle.x > self.x + self.width then
        return false
    end

    if self.y > paddle.y + paddle.height or paddle.y > self.y + self.height then
        return false
    end 

    return true
end

function Powerup:render()
    love.graphics.draw(gTextures['main'], love.graphics.newQuad(self.quadx, 192, 16, 16, gTextures['main']:getDimensions()), self.x, self.y)
end
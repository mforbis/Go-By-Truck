-- 
-- Abstract: slider component
-- 
-- Version: 0.11
-- 
-- Sample code is MIT licensed, see http://developer.anscamobile.com/code/license
-- Copyright (C) 2010 ANSCA Inc. All Rights Reserved.
 
-- TODO
-- setvalue
-- values = { }
-- documentation
-- margins

-- Version 1.2
-- Added getValue function

-- Version 1.1

-- Added Retina Support MLH

module(..., package.seeall)
 
local function newSliderHandler( self, event )
 
        local result = true
        local floor = math.floor
        
        -- General "onEvent" function overrides onPress and onRelease, if present
        local onEvent = self._onEvent
        
        local onPress = self._onPress
        local onRelease = self._onRelease
 
        local sliderEvent = { value = self.value }
        if (self._id) then
                sliderEvent.id = self._id
        else
                sliderEvent.id = 0
        end
        
        local contentX, contentY = self:localToContent(0, 0)
 
        local phase = event.phase
        if "began" == phase then
                if self.thumbOver then 
                        self.thumbDefault.isVisible = false
                        self.thumbOver.isVisible = true
                end
                
                self.thumbDefault.offsetX, self.thumbDefault.offsetY = self.thumbDefault:contentToLocal(event.x, event.y)
                
                if onEvent then
                        sliderEvent.phase = "press"
                        result = onEvent( sliderEvent )
                elseif onPress then
                        result = onPress( event )
                end
 
                -- Subsequent touch events will target slider even if they are outside the contentBounds of slider
                display.getCurrentStage():setFocus( self, event.id )
                self.isFocus = true
                
        elseif self.isFocus then
                local oldValue = self.value
 
                -- find new position of thumb
                if self.isVertical then
                        local y = (event.y - contentY) / self.yScale
                        y = y - self.thumbDefault.offsetY
                        
                        if y < self.thumbMin then
                                y = self.thumbMin
                        end
                        if y > self.thumbMax then
                                y = self.thumbMax
                        end
                        
                        local newValue = (((y - self.thumbMin) / (self.thumbMax - self.thumbMin)) * self.range) + self.minValue
                        
                        if (self.isInteger) then
                                newValue = floor(newValue + 0.5)
                        end
                        
                        self:setValue(newValue)
                else
                        local x = (event.x - contentX) / self.xScale
                        x = x - self.thumbDefault.offsetX
                        
                        if x < self.thumbMin then
                                x = self.thumbMin
                        end
                        if x > self.thumbMax then
                                x = self.thumbMax
                        end
 
                        local newValue = (((x - self.thumbMin) / (self.thumbMax - self.thumbMin)) * self.range) + self.minValue
 
                        if (self.isInteger) then
                                newValue = floor(newValue + 0.5)
                        end
 
                        self:setValue(newValue)
                end
 
                sliderEvent.value = self.value
 
                if "moved" == phase then
                        if self.value ~= oldValue then
                                if onEvent then
                                        sliderEvent.phase = "moved"
                                        result = onEvent( sliderEvent )
                                end
                        end
                elseif "ended" == phase or "cancelled" == phase then 
                        if self.thumbOver then 
                                self.thumbDefault.isVisible = true
                                self.thumbOver.isVisible = false
                        end
                        
                        if (self.snapToInteger) then
                                self:setValue(floor(self.value + 0.5))
                                sliderEvent.value = self.value
                        end
 
                        if "ended" == phase then
                                if onEvent then
                                        sliderEvent.phase = "release"
                                        result = onEvent( sliderEvent )
                                elseif onRelease then
                                        result = onRelease( event )
                                end
                        end
                        
                        -- Allow touch events to be sent normally to the objects they "hit"
                        display.getCurrentStage():setFocus( self, nil )
                        self.isFocus = false
                end
        end
 
        return result
end
 
-- newSlider( params )
-- where params is a table containing:
--              track                   - name of track image
--              thumbDefault    - name of default thumb image
--              thumbOver               - name of thumb over image (optional)
--              minValue                - min value (optional, defaults to 0)
--              maxValue                - max value (optional, defaults to 100)
--              value                   - initial value (optional, defaults to minValue)
--              isInteger               - true if integer, false if real (continuous value) (defaults to false)
--              isVertical              - true if vertical; otherwise is horizontal (defaults to horizontal)
--              onPress                 - function to call when slider is pressed
--              onRelease               - function to call when slider is released
--              onEvent                 - function to call when an event occurs
--              onChange                - function to call when value changes
--  
function newSlider( params )
        local slider
        
        slider = display.newGroup()
        
        function slider:getValue()
                return self.value
        end

        function slider:setValue(newValue)
                self.value = newValue
                
                local position = ((self.value - self.minValue) / self.range) * (self.thumbMax - self.thumbMin) + self.thumbMin
                if self.isVertical then
                        self.thumbDefault.y = position
                        self.thumbOver.y = position
                else
                        self.thumbDefault.x = position
                        self.thumbOver.x = position
                end
                
                local onChange = self._onChange
                local sliderEvent = { value = self.value }
                if (self._id) then
                        sliderEvent.id = self._id
                end
                sliderEvent.phase = "change"
                if onChange then
                        result = onChange( sliderEvent )
                end
        end
        
        -- If the trackRect is set, use it for the track
        -- else, use an image
        if params.trackRect then
                slider.track = display.newGroup()
                                
        local trackrect = display.newRoundedRect( params.trackRect.x, params.trackRect.y, params.trackRect.width, params.trackRect.height, params.trackRect.cornerRadius )
        trackrect:setFillColor( params.trackRect.fillColor.r, params.trackRect.fillColor.g, params.trackRect.fillColor.b, params.trackRect.fillColor.a )
        trackrect.strokeWidth = params.trackRect.stroke.width
        trackrect:setStrokeColor(params.trackRect.stroke.r, params.trackRect.stroke.g, params.trackRect.stroke.b, params.trackRect.stroke.a)
                slider.track:insert( trackrect )
                
                -- add tick marks
                if (params.showTickMarks) then
                        for i=1,(params.maxValue - params.minValue - 1),1 do
                                local tx = floor((i) * (params.trackRect.width / (params.maxValue - params.minValue)))
                                local t = display.newLine( slider.track, tx, 0, tx,params.trackRect.height ) 
                                t:setColor(params.trackRect.stroke.r, params.trackRect.stroke.g, params.trackRect.stroke.b, params.trackRect.stroke.a )
                                t.width = params.trackRect.stroke.width
                        end
                end
                slider:insert( slider.track, true )
                slider.track:setReferencePoint(display.CenterReferencePoint)
                slider.track.x =0
                slider.track.y =0
                
        elseif params.track then
                slider.track = display.newImageRect( params.track,params.trackDefaultSizeW,params.trackDefaultSizeH )
                slider:insert( slider.track, true )
        end
        
        if params.thumbDefault then
                slider.thumbDefault = display.newImageRect( params.thumbDefault,params.thumbDefaultSizeW,params.thumbDefaultSizeH )
                slider:insert( slider.thumbDefault, true )
        end
        
        if params.thumbOver then
                slider.thumbOver = display.newImageRect( params.thumbOver,params.thumbDefaultSizeW,params.thumbDefaultSizeH )
                slider.thumbOver.isVisible = false
                slider:insert( slider.thumbOver, true )
        end
        
        if ( params.maxValue ~= nil ) then
                slider.maxValue = params.maxValue
        else
                slider.maxValue = 100
        end
        if ( params.minValue ~= nil ) then
                slider.minValue = params.minValue
        else
                slider.minValue = 0
        end
 
        slider.range = slider.maxValue - slider.minValue
        
        if ( params.isInteger == true ) then
                slider.isInteger = true
        else
                slider.isInteger = false
        end
        
        if ( params.snapToInteger == true ) then
                slider.snapToInteger = true
        else
                slider.snapToInteger = false
        end
        
        if ( params.isVertical == true ) then
                slider.isVertical = true
        else
                slider.isVertical = false
        end
        if ( params.onPress and ( type(params.onPress) == "function" ) ) then
                slider._onPress = params.onPress
        end
        if ( params.onRelease and ( type(params.onRelease) == "function" ) ) then
                slider._onRelease = params.onRelease
        end     
        if (params.onEvent and ( type(params.onEvent) == "function" ) ) then
                slider._onEvent = params.onEvent
        end
        if(params.onChange and ( type(params.onChange) == "function" ) ) then
                slider._onChange = params.onChange
        end
 
        -- Set slider as a table listener by setting a table method and adding the slider as its own table listener for "touch" events
        slider.touch = newSliderHandler
        slider:addEventListener( "touch", slider )
 
        if params.x then
                slider.x = params.x
        end
        
        if params.y then
                slider.y = params.y
        end
        
        if params.id then
                slider._id = params.id
        end
        
                if slider.isVertical then
                        slider.thumbMin = -(slider.track.height / 2) + (slider.thumbDefault.height / 2)
                        slider.thumbMax = (slider.track.height / 2) - (slider.thumbDefault.height / 2)
                else
                        slider.thumbMin = -(slider.track.width / 2) + (slider.thumbDefault.width / 2)
                        slider.thumbMax = (slider.track.width / 2) - (slider.thumbDefault.width / 2)
                end
        
        if ( params.value ~= nil ) then
                slider:setValue(params.value)
        else
                slider:setValue(slider.minValue)
        end
 
        return slider
end
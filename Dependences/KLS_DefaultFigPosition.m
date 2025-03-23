function Pos = KLS_DefaultFigPosition()
    %---------------------------------------------------------%
    % Set a default figure position
    %---------------------------------------------------------%
    Pos = get(0,'defaultfigureposition');
    
    % Get the screen size
    screenSize = get(0, 'ScreenSize'); % screenSize = [left, bottom, width, height]
    
    % Define your figure size
    figureWidth = Pos(3); % Width of the figure
    figureHeight = Pos(4); % Height of the figure
    
    % Calculate the position to place the figure at the far left edge of the screen
    Pos = [5, screenSize(4) - figureHeight - 85, figureWidth, figureHeight]; % [left, bottom, width, height]
end
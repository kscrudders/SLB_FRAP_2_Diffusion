function out = KLS_ScaleBar(im,length,px_size,location)
%
% im = image data, [X Y ~]
% length = length of scale bar in µm
% px_size = µm/pixel
% location = string describing placement of scalebar

    % Check lenght input to see if it's not a whole number
    f = 14-9*isa(length,'single'); % double/single = 14/5 decimal places.
    s = sprintf('%.*e',f,length);
    v = [f+2:-1:3,1];
    s(v) = '0'+diff([0,cumsum(s(v)~='0')>0]);
    p = str2double(s);
    
    if p >= 1
        fomatSpec = '%.0f';
    elseif p <= 0.01
        fomatSpec = '%.2f';
    elseif p <= 0.1
        fomatSpec = '%.1f';
    end
    
    
    if nargin < 4
        location = 'otherwise';
    end
    width_x = size(im,1);
    width_y = size(im,2);

    
    switch location
        case 'northeast'
            x = [width_x-(width_x*.05) width_x-(width_x*.05)-(length/px_size)];
            y = [0+(width_y*.05) 0+(width_y*.05)];
            hold on
            plot(x,y,'Color','w','LineWidth',4)
            %text(mean(x), ...
            %    0+(width_y*.05 + width_y*.025),[num2str(length,fomatSpec) ' µm'], ...
            %    'HorizontalAlignment','center','Color','w')
        case 'northwest'
            x = [0+(width_x*.05) 0+(width_x*.05)+(length/px_size)];
            y = [0+(width_y*.05) 0+(width_y*.05)];
            hold on
            plot(x,y,'Color','w','LineWidth',4)
            %text(mean(x), ...
            %   0+(width_y*.05 + width_y*.025),[num2str(length,fomatSpec) ' µm'], ...
            %    'HorizontalAlignment','center','Color','w')
        case 'southwest'
            x = [0+(width_x*.05) 0+(width_x*.05)+(length/px_size)];
            y = [width_y-(width_y*.05) width_y-(width_y*.05)];
            hold on
            plot(x,y,'Color','w','LineWidth',4)
            %text(mean(x), ...
            %   width_y-(width_y*.025),[num2str(length,fomatSpec) ' µm'], ...
            %    'HorizontalAlignment','center','Color','w')
        otherwise % default southeast
            x = [width_x-(width_x*.05) width_x-(width_x*.05)-(length/px_size)];
            y = [width_y-(width_y*.05) width_y-(width_y*.05)];
            hold on
            plot(x,y,'Color','w','LineWidth',4)
            %text(mean(x), ...
            %   width_y-(width_y*.025),[num2str(length,fomatSpec) ' µm'], ...
            %    'HorizontalAlignment','center','Color','w')
    end    
end
function textColor = determineTextColorForBackground(bgColor)
%DETERMINETEXTCOLORFORBACKGROUND Choose text color based on background
%   textColor = determineTextColorForBackground(bgColor) returns white
%   or black text color based on background luminance for optimal
%   contrast.
%
%   Uses the relative luminance formula to determine contrast.

    rgb = conduction.visualization.colors.normalizeColorSpec(bgColor);
    luminance = sum(rgb .* [0.299, 0.587, 0.114]);
    if luminance < 0.5
        textColor = [1 1 1];  % White text for dark backgrounds
    else
        textColor = [0 0 0];  % Black text for light backgrounds
    end
end

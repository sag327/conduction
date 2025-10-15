function flag = ischarLike(value)
%ISCHARLIKE Check if value is char or scalar string
%   flag = ischarLike(value) returns true if value is a character
%   array or a scalar string.

    flag = ischar(value) || (isstring(value) && isscalar(value));
end

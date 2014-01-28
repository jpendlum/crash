%------------------------------------------------------------------------------
%-  Copyright 2013-2014 Jonathon Pendlum
%-
%-  This is free software: you can redistribute it and/or modify
%-  it under the terms of the GNU General Public License as published by
%-  the Free Software Foundation, either version 3 of the License, or
%-  (at your option) any later version.
%-
%-  This is distributed in the hope that it will be useful,
%-  but WITHOUT ANY WARRANTY; without even the implied warranty of
%-  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%-  GNU General Public License for more details.
%-
%-  You should have received a copy of the GNU General Public License
%-  along with this program.  If not, see <http://www.gnu.org/licenses/>.
%-
%-
fp = fopen('data.txt','r');
A = fread(fp,8192,'float');
fclose(fp);
I = A(1:2:end);
Q = A(2:2:end);

Fs = 100e6/8;
L = length(I);
NFFT = 2^16;
Y = fft(I + Q.*j,NFFT)/L;
f = Fs/2*linspace(-1,1,NFFT);

figure;
subplot(2,1,1);
plot(I);
subplot(2,1,2);
plot(f/1e6,20*log10(abs(fftshift(Y))))
title('FFT of y(t)')
xlabel('Frequency (MHz)')
ylabel('|Y(f)|')
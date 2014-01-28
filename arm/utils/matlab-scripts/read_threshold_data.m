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
%-  along with this software.  If not, see <http://www.gnu.org/licenses/>.
%-
%-
nfft = 64;
fp = fopen('data.txt','r');
A = fread(fp,2*nfft,'float');
fclose(fp);
I = A(1:2:end);
Q = A(2:2:end);

Fs = 100e6/nfft;
f = Fs/2*linspace(-1,1,nfft);
subplot(2,1,1);
plot(fftshift(I));
subplot(2,1,2);
plot(fftshift(20*log10(I)));
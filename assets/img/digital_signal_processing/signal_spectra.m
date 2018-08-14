clear; clc; close all;

Fs = 1e6;
samples = Fs;% / 1000;
t = (0:1/Fs:1e-3)';
Fc = 1e4;
x = exp(1i*2*pi*Fc*t);
x(1:length(x)/2) = x(1:length(x)/2) * -1;

figure
plot(t,real(x));
hold on   
plot(t,imag(x));
xlabel('Time, seconds');
ylabel('Signal');  
title('Complex signal')
zoom
grid

figure
plot(t,real(fft(x)));
hold on
plot(t,imag(fft(x)));
xlabel('Time, seconds');
ylabel('Signal');  
title('Complex signal')
zoom
grid

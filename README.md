List github repos on your system and bulk update.  

Youtube:  
[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/qHccZ08nVq4/0.jpg)](https://www.youtube.com/watch?v=qHccZ08nVq4)  

img  
![ahk-git-updater](https://github.com/user-attachments/assets/fa2d0903-11a4-4234-a5a2-39e983900af4)


A simpler approach with a batch script:  
```bat
:: updateGtiRepos.bat
:: %cd% means to to loop all folders in the script's dir
:: or you can pass a specific folder "C:\dir"
@echo off
for /f %%f in ('dir /ad /b %cd%') do (
    cd /d %cd%\%%f
    call git pull
    cd ..
)
pause
```

-- Developer A/B switches via engine args; no saved gameplay state is changed.
local S={legacy=false,profile=false,fps=60,hostPaced=false,reportHost="maker-or-native-runtime"}
if GetArguments then for _,arg in ipairs(GetArguments())do
 if arg=="-ocean=legacy" then S.legacy=true end
 if arg=="-oceanprofile" or arg=="-oceanprofile=1" then S.profile=true end
 if arg=="-hostpacing" then S.hostPaced=true end
 if arg=="-reporthost=public-web" then S.reportHost="public-web" end
 local fps=tonumber(arg:match("^%-fps=(%d+)$"))
 if fps and fps>=30 and fps<=120 then S.fps=math.floor(fps)end
end end
return S

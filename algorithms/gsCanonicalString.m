function key = gsCanonicalString(gs,mapping)
%GSCANONICALSTRING Validated length-prefixed labels (including multi-digit keys).
decodeGS(gs,mapping);
gs=reshape(gs,1,[]);
key="GS1|"+join(string(strlength(gs))+":"+gs,"|");
end

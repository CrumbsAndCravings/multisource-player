' Small wrappers around the Roku registry (persistent key/value storage on the TV).
' Tests swap this file for tests/fake_registry.brs.

function RegRead(section as String, key as String) as Dynamic
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(key) then return sec.Read(key)
    return invalid
end function

sub RegWrite(section as String, key as String, value as String)
    sec = CreateObject("roRegistrySection", section)
    sec.Write(key, value)
    sec.Flush()
end sub

sub RegDelete(section as String, key as String)
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(key)
    sec.Flush()
end sub

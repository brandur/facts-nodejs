# Stolen from http://www.broofa.com/Tools/Math.uuid.js
CHARS = "0123456789abcdef".split("")
exports.make: ->
    chars: CHARS
    uuid: new Array(36)
    rnd: 0
    for i in [0..36]
        switch i
            when 8, 13, 18, 23
                uuid[i]: '-'
            else
                if rnd <= 0x02
                    rnd: 0x2000000 + (Math.random() * 0x1000000) | 0
                r: rnd & 0xf
                rnd: rnd >> 4
                uuid[i]: chars[if i == 19 then (r & 0x3) | 0x8 else r]
    return uuid.join ""


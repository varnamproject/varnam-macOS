# VarnamIME for macOS

Easily type Indian languages on macOS using [Varnam transliteration engine](https://varnamproject.github.io/).

Built at FOSSUnited's [FOSSHack21](https://fossunited.org/fosshack/2021/project?project=Type%20Indian%20Languages%20natively%20on%20Mac).

This project is a hard-fork of [lipika-ime](https://github.com/ratreya/Lipika_IME). Changes made:
* https://github.com/varnamproject/varnam-macOS/pull/1

There aren't many documentation on how to make IMEs for macOS, especially in **English**. Getting started with XCode is also tricky for beginners. Setting up **Lipika** was also difficult.

Resources that helped in making IME on macOS (ordered by most important to the least):
* https://blog.inoki.cc/2021/06/19/Write-your-own-IME-on-macOS-1/ (The last section is very important!)
* https://jyhong836.github.io/tech/2015/07/29/add-3rd-part-dynamic-library-dylib-to-xcode-target.html
* https://github.com/lennylxx/google-input-tools-macos (An IME made 2 months ago, Has GitHub CI builds)
* https://github.com/nh7a/hiragany (Simple Japanese IME)
* https://github.com/pkamb/NumberInput_IMKit_Sample/issues/1
* API Docs: https://developer.apple.com/documentation/inputmethodkit/imkcandidates

## License

> Copyright (C) 2018 Ranganath Atreya
>
> Copyright (C) 2021 Subin Siby

```
This program is free software: you can redistribute it and/or modify it under the terms of the GNU 
General Public License as published by the Free Software Foundation; either version 3 of the License, 
or (at your option) any later version.

This program comes with ABSOLUTELY NO WARRANTY; see LICENSE file.
```

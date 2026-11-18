let enableThreads = false;
            const queryString = window.location.search;
            const urlParams = new URLSearchParams(queryString);
            if (parseInt(urlParams.get('threads')) === 1 || urlParams.get('threads') === "true") {
                if (window.SharedArrayBuffer) {
                    enableThreads = true;
                    console.log("Threads are enabled");
                } else {
                    console.warn("Threads are disabled as SharedArrayBuffer is not available. Threads requires two headers to be set when sending you html page. See https://stackoverflow.com/a/68630724");
                    console.log("Threads are disabled");
                }
            } else {
                console.log("Threads are disabled");
            }

            if (urlParams.get('rom')) {
                console.log(`Loading ROM from URL: roms/${urlParams.get('rom')}`);
                run(false, urlParams.get('rom'));
            }

            async function run(upload, file, selection) {
                const url = selection?.url || (upload ? input.files[0] : `roms/${file}`);
                const parts = (selection?.filename || (upload ? input.files[0].name : file)).split(".");

                const core = selection?.core || await (async (ext) => {
                    if (["fds", "nes", "unif", "unf"].includes(ext))
                        return "nes"

                    if (["smc", "fig", "sfc", "gd3", "gd7", "dx2", "bsx", "swc"].includes(ext))
                        return "snes"

                    if (["z64", "n64"].includes(ext))
                        return "n64"

                    if (["pce"].includes(ext))
                        return "pce"

                    if (["ngp", "ngc"].includes(ext))
                        return "ngp"

                    if (["ws", "wsc"].includes(ext))
                        return "ws"

                    if (["col", "cv"].includes(ext))
                        return "coleco"

                    if (["d64"].includes(ext))
                        return "vice_x64sc"

                    if (["nds", "gba", "gb", "z64", "n64"].includes(ext))
                        return ext

                    return await new Promise(resolve => {
                        var coreValues = {
                            "Nintendo 64": "n64",
                            "Nintendo Game Boy": "gb",
                            "Nintendo Game Boy Advance": "gba",
                            "Nintendo DS": "nds",
                            "Nintendo Entertainment System": "nes",
                            "Super Nintendo Entertainment System": "snes",
                            "PlayStation": "psx",
                            "PlayStation Portable": "ppsspp",
                            "DOS": "dosbox_pure",
                            "Virtual Boy": "vb",
                            "Sega Mega Drive": "segaMD",
                            "Sega Master System": "segaMS",
                            "Sega CD": "segaCD",
                            "Atari Lynx": "lynx",
                            "Sega 32X": "sega32x",
                            "Atari Jaguar": "jaguar",
                            "Sega Game Gear": "segaGG",
                            "Sega Saturn": "segaSaturn",
                            "Atari 7800": "atari7800",
                            "Atari 2600": "atari2600",
                            "Arcade": "arcade",
                            "NEC TurboGrafx-16/SuperGrafx/PC Engine": "pce",
                            "NEC PC-FX": "pcfx",
                            "SNK NeoGeo Pocket (Color)": "ngp",
                            "Bandai WonderSwan (Color)": "ws",
                            "ColecoVision": "coleco",
                            "Commodore 64": "vice_x64sc",
                            "Commodore 128": "vice_x128",
                            "Commodore VIC20": "vice_xvic",
                            "Commodore Plus/4": "vice_xplus4",
                            "Commodore PET": "vice_xpet"
                        }

                        const cores = Object.keys(coreValues).sort().reduce(
                            (obj, key) => { 
                                obj[key] = coreValues[key]; 
                                return obj;
                            }, 
                            {}
                        );

                        const button = document.createElement("button")
                        const select = document.createElement("select")

                        for (const type in cores) {
                            const option = document.createElement("option")

                            option.value = cores[type]
                            option.textContent = type
                            select.appendChild(option)
                        }

                        button.onclick = () => resolve(select[select.selectedIndex].value)
                        button.textContent = "Load game"
                        box.innerHTML = ""

                        box.appendChild(select)
                        box.appendChild(button)
                    })
                })(parts.pop())

                const hostOptions = await window.reaEmulatorBeforeStart(core);

                const div = document.createElement("div")
                const sub = document.createElement("div")
                const script = document.createElement("script")

                sub.id = "game"
                div.id = "display"

                const top = document.getElementById("top");
                top.remove();
                box.remove()
                div.appendChild(sub)
                document.body.appendChild(div)

                window.EJS_player = "#game";
                window.EJS_gameName = selection?.name || parts.shift();
                window.EJS_biosUrl = "";
                window.EJS_gameUrl = url;
                window.EJS_core = core;
                window.EJS_pathtodata = "vendor/emulatorjs/data/";
                window.EJS_startOnLoaded = true;
                window.EJS_disableDatabases = true;
                window.EJS_threads = enableThreads;

                Object.assign(window, hostOptions);
                script.src = "vendor/emulatorjs/data/loader.js";
                await new Promise((resolve, reject) => {
                    script.addEventListener("load", resolve, { once: true });
                    script.addEventListener("error", () => reject(new Error("Could not load EmulatorJS loader")), { once: true });
                    document.body.appendChild(script);
                });
            }
            
            input.onchange = async () => {
                run(true).catch(error => alert("ReaEmulator: " + error.message));
            }
            
            box.ondragover = () => box.setAttribute("drag", true);
            box.ondragleave = () => box.removeAttribute("drag");

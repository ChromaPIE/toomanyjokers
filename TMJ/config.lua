TMJ.fake_config = {
    rows = tostring(TMJ.config.rows),
    columns = tostring(TMJ.config.columns),
    size = tostring(TMJ.config.size),
    sensitivity = tostring(TMJ.config.sensitivity),
}

TMJ.config_tab = function()
    return {
        n = G.UIT.ROOT,
        config = { align = "cm", minh = G.ROOM.T.h * 0.25, padding = 0.0, r = 0.1, colour = G.C.GREY },
        nodes = {
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_text_input({
                                colour = G.C.RED,
                                align = "cl",
                                hooked_colour = darken(copy_table(G.C.RED), 0.3),
                                w = 2,
                                h = 1,
                                max_length = 3,
                                extended_corpus = true,
                                prompt_text = "",
                                id = "TMJROWS",
                                ref_table = TMJ.fake_config,
                                ref_value = "rows"
                            }),
                            { n = G.UIT.T, config = { text = localize("tmj_config_rows"), align = "cr", colour = G.C.WHITE, scale = 0.35 } },
                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_text_input({
                                colour = G.C.RED,
                                align = "cl",
                                hooked_colour = darken(copy_table(G.C.RED), 0.3),
                                w = 2,
                                h = 1,
                                max_length = 3,
                                extended_corpus = true,
                                prompt_text = "",
                                id = "TMJCOLS",
                                ref_table = TMJ.fake_config,
                                ref_value = "columns"
                            }),
                            { n = G.UIT.T, config = { align = "cr", text = localize("tmj_config_columns"), colour = G.C.WHITE, scale = 0.35 } },

                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_text_input({
                                align = "cl",
                                colour = G.C.RED,
                                hooked_colour = darken(copy_table(G.C.RED), 0.3),
                                w = 2,
                                h = 1,
                                max_length = 4,
                                extended_corpus = true,
                                prompt_text = "",
                                id = "TMJSIZE",
                                ref_table = TMJ.fake_config,
                                ref_value = "size"
                            }),
                            { n = G.UIT.T, config = { align = "cr", text = localize("tmj_config_size"), colour = G.C.WHITE, scale = 0.35 } },

                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_text_input({
                                align = "cl",
                                colour = G.C.RED,
                                hooked_colour = darken(copy_table(G.C.RED), 0.3),
                                w = 2,
                                h = 1,
                                max_length = 4,
                                extended_corpus = true,
                                prompt_text = "",
                                id = "TMJSENS",
                                ref_table = TMJ.fake_config,
                                ref_value = "sensitivity"
                            }),
                            { n = G.UIT.T, config = { align = "cr", text = localize("tmj_config_sensitivity"), colour = G.C.WHITE, scale = 0.35 } },
                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_toggle {
                                label = localize("tmj_config_hide_undiscovered"),
                                ref_table = TMJ.config,
                                ref_value = "hide_undiscovered"
                            },
                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_toggle {
                                label = localize("tmj_config_close_on_esc"),
                                ref_table = TMJ.config,
                                ref_value = "close_on_esc"
                            },
                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_toggle {
                                label = localize("tmj_config_scroll_full_page"),
                                ref_table = TMJ.config,
                                ref_value = "scroll_full_page"
                            },
                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_toggle {
                                label = localize("tmj_config_arrow_key_scroll"),
                                ref_table = TMJ.config,
                                ref_value = "arrow_key_scroll"
                            },
                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_toggle {
                                label = localize("tmj_config_autofocus"),
                                ref_table = TMJ.config,
                                ref_value = "autofocus"
                            },
                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_toggle {
                                label = localize("tmj_config_show_all_tags"),
                                ref_table = TMJ.config,
                                ref_value = "show_all_tags",
                                callback = function()
                                    TMJ.MODCACHE = nil
                                end
                            },
                        }
                    }
                }
            },
            {
                n = G.UIT.R,
                config = { align = "cl" },
                nodes = {
                    {
                        n = G.UIT.C,
                        config = { align = "cl", padding = 0.1 },
                        nodes = {
                            create_toggle {
                                label = localize("tmj_config_hide_no_collection"),
                                ref_table = TMJ.config,
                                ref_value = "hide_no_collection",
                                callback = function()
                                    TMJ.MODCACHE = nil
                                end
                            },
                        }
                    }
                }
            },
            TMJ.FUNCS.CHEAT_TOGGLE(),

        }
    }
end

TMJ.FUNCS.CHEAT_TOGGLE = function()
    if not _RELEASE_MODE then
        return {
            n = G.UIT.R,
            config = { align = "cl" },
            nodes = {
                {
                    n = G.UIT.C,
                    config = { align = "cl", padding = 0.1 },
                    nodes = {
                        create_toggle {
                            label = localize("tmj_config_disable_cheats"),
                            ref_table = TMJ.config,
                            ref_value = "disable_cheats"
                        },
                    }
                }
            }
        }
    end
end

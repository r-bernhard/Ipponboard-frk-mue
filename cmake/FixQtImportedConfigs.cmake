# Workaround: A Qt install whose CMake package files export only the Debug
# configuration (e.g. a debug build installed over a release-only prefix)
# makes CMake silently link the debug Qt libraries (/MDd) into Release builds.
# The mixed CRT runtimes corrupt QString/QByteArray heap ownership across
# module boundaries. If the package lacks Release entries but the release
# libraries exist, patch the imported targets so each configuration links
# its own Qt runtime.
#
# This project is Qt6-only, so the Qt5 fallback of the original workaround
# is omitted.
#
# Include this file in the top-level CMakeLists.txt before the find_package()
# call that creates the imported targets, because CMake commands are only
# visible after their definition is processed. The imported targets must be
# created in the top-level scope (directory-scoped otherwise), so the
# find_package() call must also live in the top-level CMakeLists.txt.
function(fix_qt_imported_configs qtdir)
    if(NOT MSVC)
        return()
    endif()
    foreach(module
            Core Gui Widgets Network Core5Compat PrintSupport Multimedia XmlPatterns
            EntryPointImplementation)
        if(NOT TARGET Qt6::${module})
            continue()
        endif()
        # Qt6EntryPointImplementation is a STATIC helper whose file is named
        # Qt6EntryPoint[.lib|d.lib], unlike the shared modules (Qt6<Module>).
        set(libname ${module})
        if(module STREQUAL "EntryPointImplementation")
            set(libname "EntryPoint")
        endif()
        get_target_property(target_type Qt6::${module} TYPE)
        if(NOT target_type MATCHES "SHARED")
            get_target_property(rel_loc Qt6::${module} IMPORTED_LOCATION_RELEASE)
        else()
            get_target_property(rel_loc Qt6::${module} IMPORTED_IMPLIB_RELEASE)
        endif()
        if(rel_loc)
            continue()
        endif()
        set(release_lib "${qtdir}/lib/Qt6${libname}.lib")
        set(release_dll "${qtdir}/bin/Qt6${libname}.dll")
        if(NOT target_type MATCHES "SHARED")
            if(NOT EXISTS "${release_lib}")
                message(WARNING "Qt6::${module} exports no Release configuration and ${release_lib} is missing; Release builds will link debug Qt libraries")
                continue()
            endif()
        elseif(NOT (EXISTS "${release_lib}" AND EXISTS "${release_dll}"))
            message(WARNING "Qt6::${module} exports no Release configuration and ${release_lib} is missing; Release builds will link debug Qt libraries")
            continue()
        endif()
        get_target_property(cfgs Qt6::${module} IMPORTED_CONFIGURATIONS)
        if(cfgs STREQUAL "cfgs-NOTFOUND")
            set(cfgs "")
        endif()
        if(NOT ";${cfgs};" MATCHES ";Release;")
            set_property(TARGET Qt6::${module} APPEND PROPERTY IMPORTED_CONFIGURATIONS Release)
        endif()
        if(NOT target_type MATCHES "SHARED")
            set_target_properties(Qt6::${module} PROPERTIES
                IMPORTED_LOCATION_RELEASE "${release_lib}"
            )
        else()
            set_target_properties(Qt6::${module} PROPERTIES
                IMPORTED_LOCATION_RELEASE "${release_dll}"
                IMPORTED_IMPLIB_RELEASE "${release_lib}"
            )
        endif()
        message(STATUS "Qt6::${module} exports no Release configuration; patched to use ${release_lib}")
    endforeach()
endfunction()

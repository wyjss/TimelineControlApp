# find osg and osgearth
# OE_FOUND

set(OE_TARGETS)
set(OE_RUN_PATH)

set(CUS_OSG_LIBRARIES
    osg OpenThreads
    osgAnimation
    osgDB
    osgFX
    osgGA
    osgManipulator
    osgParticle
    osgPresentation
    osgShadow
    osgSim
    osgTerrain
    osgText
    osgUtil
    osgViewer
    osgVolume
)

find_package(OpenSceneGraph COMPONENTS ${CUS_OSG_LIBRARIES} CONFIG REQUIRED )
foreach(v ${CUS_OSG_LIBRARIES})
    list(APPEND OE_TARGETS osg3::${v})
endforeach()

find_package(osgearth CONFIG REQUIRED)
list(APPEND OE_TARGETS osgEarth::osgEarth)



set(OE_FOUND ON)
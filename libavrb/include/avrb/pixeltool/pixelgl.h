#pragma once

#include "pixeltool/pixeldata.h"

namespace PixelTool {
	struct PIXELTOOL_EXPORT PixelTextures : public PixelChannelLayout {
		uint textureY;
		int indexY;
		int locationY;
		uint textureU;
		int indexU;
		int locationU;
		uint textureV;
		int indexV;
		int locationV;

		uint program;
		PixelTextures() :program(0) {}
	};


	PIXELTOOL_EXPORT PixelTextures* GenTextures(int pixelType, const QSize& size, int indexStart = 6, PixelTextures* src = nullptr);
	PIXELTOOL_EXPORT void DeleteTextures(PixelTextures* textures);
	PIXELTOOL_EXPORT void UpdateTextures(PixelTextures* textures, const PixelData* data);
	PIXELTOOL_EXPORT void BindTextures(PixelTextures* textures, uint program = 0);

	/**
	* 返回glsl取像色颜色的函数void getPixelColor(inout vec4 outColor, vec2 texcoord);
	*/
	PIXELTOOL_EXPORT QString GenPixelColorFunction(int pixelType, const PixelTextures* textures = nullptr);

	PIXELTOOL_EXPORT QString GenPixelVertShader();
	PIXELTOOL_EXPORT QString GenPixelFragShader(int pixelType, const PixelTextures* textures = nullptr);


};
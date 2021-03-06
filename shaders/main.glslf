#version GLSL_VERSION

/*==============================================================================
                                    VARS
==============================================================================*/
#var PRECISION highp

#var SHADELESS 0
#var CAUSTICS 0
#var USE_ENVIRONMENT_LIGHT 0
#var SKY_TEXTURE 0
#var SKY_COLOR 0
#var NORMAL_TEXCOORD 0
#var USE_VIEW_TSR 0
#var USE_VIEW_TSR_INVERSE 0
#var USE_MODEL_TSR 0
#var USE_MODEL_TSR_INVERSE 0
#var USE_PROJ_MATRIX_FRAG 0
#var WATER_EFFECTS 0
#var USE_FOG 0
#var CALC_TBN_SPACE 0
#var TEXTURE_NORM_CO TEXTURE_COORDS_NONE
#var PARALLAX 0
#var USE_TBN_SHADING 0
#var CAMERA_TYPE CAM_TYPE_PERSP
#var USE_POSITION_CLIP 0
#var RGBA_SHADOWS 0
#var USE_BSDF_SKY_DIM 0

#var NODES 0
#var ALPHA 0
#var ALPHA_CLIP 0
#var WETTABLE 0
#var NUM_VALUES 0
#var NUM_RGBS 0
#var DISABLE_FOG 0
#var SHADOW_USAGE NO_SHADOWS
#var NUM_LIGHTS 0
#var NUM_LAMP_LIGHTS 0
#var SSAO_ONLY 0
#var REFLECTION_TYPE REFL_NONE
#var PROCEDURAL_FOG 0
#var REFRACTIVE 0
#var USE_REFRACTION 0
#var USE_REFRACTION_CORRECTION 0

#var CSM_SECTION1 0
#var CSM_SECTION2 0
#var CSM_SECTION3 0
#var NUM_CAST_LAMPS 0

#var WATER_LEVEL 0.0
#var POISSON_DISK_NUM NO_SOFT_SHADOWS

#var USE_DERIVATIVES_EXT 0
#var USE_TEXTURE_LOD_EXT 0

#var USE_LOD_SMOOTHING 0

# if GLSL1 && USE_DERIVATIVES_EXT
#extension GL_OES_standard_derivatives: enable
# endif

# if GLSL1 && USE_TEXTURE_LOD_EXT
#extension GL_EXT_shader_texture_lod: enable
# endif

/*==============================================================================
                                  INCLUDES
==============================================================================*/
#include <precision_statement.glslf>
#include <std.glsl>

#include <color_util.glslf>
#include <math.glslv>

#if USE_LOD_SMOOTHING
#include <coverage.glslf>
#endif

#if !SHADELESS
# if CAUSTICS
#include <caustics.glslf>
# endif
#endif

#if RGBA_SHADOWS || USE_REFRACTION_CORRECTION
#include <pack.glslf>
#endif


/*==============================================================================
                               GLOBAL UNIFORMS
==============================================================================*/

uniform float u_time;
uniform vec2 u_texel_size;

#if USE_ENVIRONMENT_LIGHT && SKY_TEXTURE
uniform samplerCube u_sky_texture;
#elif USE_ENVIRONMENT_LIGHT && SKY_COLOR
uniform vec3 u_horizon_color;
uniform vec3 u_zenith_color;
#endif

#if GLSL1 && USE_BSDF_SKY_DIM
    uniform float u_bsdf_cube_sky_dim;
#endif

uniform float u_environment_energy;

#if !SHADELESS

# if NUM_LIGHTS > 0
// light_factors packed in the w componnets
uniform vec4 u_light_positions[NUM_LIGHTS];
uniform vec3 u_light_directions[NUM_LIGHTS];
uniform vec4 u_light_color_intensities[NUM_LIGHTS];
# endif

# if CAUSTICS
uniform vec4 u_sun_quaternion;
uniform vec3 u_sun_intensity;
uniform vec3 u_sun_direction;
# endif
#endif

uniform vec3 u_camera_eye_frag;

#if (USE_NODE_FRESNEL || USE_NODE_LAYER_WEIGHT) && CAMERA_TYPE == CAM_TYPE_ORTHO
uniform vec3 u_camera_direction;
#endif

#if NORMAL_TEXCOORD || REFLECTION_TYPE == REFL_PLANE || USE_VIEW_TSR
uniform mat3 u_view_tsr_frag;
#endif

#if USE_VIEW_TSR_INVERSE
uniform mat3 u_view_tsr_inverse;
#endif
#if USE_MODEL_TSR
// it's always dynamic object
uniform mat3 u_model_tsr;
#endif
#if USE_MODEL_TSR_INVERSE
uniform mat3 u_model_tsr_inverse;
#endif
#if USE_PROJ_MATRIX_FRAG
uniform mat4 u_proj_matrix_frag;
#endif

#if !DISABLE_FOG
uniform vec4 u_fog_color_density;
# if WATER_EFFECTS
uniform vec4 u_underwater_fog_color_density;
uniform float u_cam_water_depth;
# endif
# if PROCEDURAL_FOG
uniform mat4 u_cube_fog;
# endif
# if USE_FOG
uniform vec4 u_fog_params; // intensity, depth, start, height
# endif
#endif

#if USE_LOD_SMOOTHING
uniform float u_lod_coverage;
uniform float u_lod_cmp_logic;
#endif

/*==============================================================================
                               SAMPLER UNIFORMS
==============================================================================*/

#if REFLECTION_TYPE == REFL_PLANE
uniform sampler2D u_plane_reflection;
#elif REFLECTION_TYPE == REFL_CUBE
uniform samplerCube u_cube_reflection;
#elif REFLECTION_TYPE == REFL_MIRRORMAP
uniform samplerCube u_mirrormap;
#elif  REFLECTION_TYPE == REFL_PBR_SIMPLE
uniform samplerCube u_sky_reflection;
#elif REFLECTION_TYPE == REFL_PBR_STANDARD
uniform samplerCube u_cube_irradiance;
uniform samplerCube u_cube_r_convolution;
uniform sampler2D   u_brdf;
#endif

#if SHADOW_USAGE == SHADOW_MAPPING_OPAQUE
uniform sampler2D u_shadow_mask;
#elif SHADOW_USAGE == SHADOW_MAPPING_BLEND
# if POISSON_DISK_NUM != NO_SOFT_SHADOWS
uniform vec4 u_pcf_blur_radii;
# endif
uniform vec4 u_csm_center_dists;
uniform PRECISION GLSL_SMPLR2D_SHDW u_shadow_map0;
# if CSM_SECTION1 || NUM_CAST_LAMPS > 1
uniform PRECISION GLSL_SMPLR2D_SHDW u_shadow_map1;
# endif
# if CSM_SECTION2 || NUM_CAST_LAMPS > 2
uniform PRECISION GLSL_SMPLR2D_SHDW u_shadow_map2;
# endif
# if CSM_SECTION3 || NUM_CAST_LAMPS > 3
uniform PRECISION GLSL_SMPLR2D_SHDW u_shadow_map3;
# endif
#endif

#if REFRACTIVE || USE_NODE_B4W_REFRACTION
uniform sampler2D u_refractmap;
#endif

#if (USE_NODE_B4W_REFRACTION || USE_NODE_BSDF_PRINCIPLED) && USE_REFRACTION && REFRACTIVE && USE_REFRACTION_CORRECTION
uniform PRECISION sampler2D u_scene_depth;
#endif

/*==============================================================================
                               MATERIAL UNIFORMS
==============================================================================*/

uniform float u_emit;
uniform float u_ambient;
uniform vec2  u_fresnel_params;

#if REFLECTION_TYPE == REFL_PLANE || REFLECTION_TYPE == REFL_CUBE
#elif REFLECTION_TYPE == REFL_MIRRORMAP
uniform float u_mirror_factor;
#endif

#if REFLECTION_TYPE == REFL_PLANE
uniform vec4 u_refl_plane;
#endif

#if USE_NODE_LAMP && NUM_LAMP_LIGHTS != 0
uniform vec3 u_lamp_light_positions[NUM_LAMP_LIGHTS];
uniform vec3 u_lamp_light_directions[NUM_LAMP_LIGHTS];
uniform vec3 u_lamp_light_color_intensities[NUM_LAMP_LIGHTS];
#endif

#if USE_NODE_VALUE
uniform vec4 u_node_values[NUM_VALUES];
#endif

#if USE_NODE_RGB
uniform vec3 u_node_rgbs[NUM_RGBS];
#endif

#if USE_NODE_CURVE_VEC || USE_NODE_CURVE_RGB || USE_NODE_VALTORGB
uniform sampler2D u_nodes_texture;
#endif

#if USE_NODE_OBJECT_INFO
uniform vec3 u_obj_info;
#endif

/*==============================================================================
                                SHADER INTERFACE
==============================================================================*/
GLSL_IN vec3 v_pos_world;
GLSL_IN vec3 v_normal;

#if NODES || !DISABLE_FOG || (TEXTURE_NORM_CO != TEXTURE_COORDS_NONE && PARALLAX) \
        || (!SHADELESS && CAUSTICS && WATER_EFFECTS) \
        || SHADOW_USAGE == SHADOW_MASK_GENERATION || SHADOW_USAGE == SHADOW_MAPPING_BLEND
GLSL_IN vec4 v_pos_view;
#endif

#if TEXTURE_NORM_CO != TEXTURE_COORDS_NONE || CALC_TBN_SPACE
GLSL_IN vec4 v_tangent;
#endif

#if USE_TBN_SHADING
GLSL_IN vec3 v_shade_tang;
#endif

#if SHADOW_USAGE == SHADOW_MAPPING_BLEND
GLSL_IN vec4 v_shadow_coord0;
# if CSM_SECTION1 || NUM_CAST_LAMPS > 1
GLSL_IN vec4 v_shadow_coord1;
# endif
# if CSM_SECTION2 || NUM_CAST_LAMPS > 2
GLSL_IN vec4 v_shadow_coord2;
# endif
# if CSM_SECTION3 || NUM_CAST_LAMPS > 3
GLSL_IN vec4 v_shadow_coord3;
# endif
#endif

#if REFLECTION_TYPE == REFL_PLANE || SHADOW_USAGE == SHADOW_MAPPING_OPAQUE \
        || REFRACTIVE || USE_POSITION_CLIP
GLSL_IN vec3 v_tex_pos_clip;
#endif

#if REFRACTIVE && USE_NODE_B4W_REFRACTION
GLSL_IN float v_view_depth;
#endif
//------------------------------------------------------------------------------

GLSL_OUT vec4 GLSL_OUT_FRAG_COLOR;

/*==============================================================================
                                  INCLUDES
==============================================================================*/

#include <nodes.glslf>

#if !DISABLE_FOG
#include <fog.glslf>
#endif

/*==============================================================================
                                    MAIN
==============================================================================*/

void main(void) {

#if USE_LOD_SMOOTHING
    if (!coverage_is_frag_visible(u_lod_coverage, u_lod_cmp_logic))
        discard;
#endif

#if NODES || !DISABLE_FOG || (TEXTURE_NORM_CO != TEXTURE_COORDS_NONE && PARALLAX) \
        || (!SHADELESS && CAUSTICS && WATER_EFFECTS)
    float view_dist = length(v_pos_view);
#endif

#if WATER_EFFECTS
    float dist_to_water = v_pos_world.z - WATER_LEVEL;
#endif

    vec3 eye_dir = normalize(u_camera_eye_frag - v_pos_world);
    vec3 nout_color;
    vec3 nout_specular_color;
    vec3 nout_normal;
    vec4 nout_shadow_factor;
    float nout_alpha;

    nodes_main(eye_dir,
            nout_color,
            nout_specular_color,
            nout_normal,
            nout_shadow_factor,
            nout_alpha);

    vec3 color = nout_color;
    float alpha = nout_alpha;
    vec3 normal = nout_normal;
    vec4 shadow_factor = nout_shadow_factor;

#if !SHADELESS && WATER_EFFECTS
# if WETTABLE
    //darken slightly to simulate wet surface
    color = max(color - sqrt(0.01 * -min(dist_to_water, 0.0)), 0.5 * color);
# endif
# if CAUSTICS
    apply_caustics(color, dist_to_water, u_time, shadow_factor, normal,
                   u_sun_direction, u_sun_intensity, u_sun_quaternion,
                   v_pos_world, view_dist);
# endif  // CAUSTICS
#endif  //SHADELESS

#if ALPHA
# if ALPHA_CLIP
    if (alpha < 0.5)
        discard;
    alpha = 1.0; // prevent blending with html content
# else
    alpha = min(1.0, alpha);
# endif  // ALPHA CLIP
#else  // ALPHA
    alpha = 1.0;
#endif  // ALPHA

#if !DISABLE_FOG
# if WATER_EFFECTS
    fog(color, view_dist, eye_dir, dist_to_water);
# else
    fog(color, view_dist, eye_dir, 1.0);
# endif
#endif

#if SSAO_ONLY && SHADOW_USAGE == SHADOW_MAPPING_OPAQUE
    float ssao = GLSL_TEXTURE_PROJ(u_shadow_mask, v_tex_pos_clip).a;
    color = vec3(ssao);
#endif

    color = max(vec3(0.0), color);
    lin_to_srgb(color);
#if ALPHA && !ALPHA_CLIP
    premultiply_alpha(color, alpha);
#endif

    GLSL_OUT_FRAG_COLOR = vec4(color, alpha);
}

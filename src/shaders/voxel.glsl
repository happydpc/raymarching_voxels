
// this seems like a pretty hacky solution to getting access to voxel data when included
#ifndef VOXEL_BINDING_OFFSET
#define VOXEL_BINDING_OFFSET (0)
#endif
/// datastructures and methods for processing voxel data

#define VOXEL_BINDING_END (VOXEL_BINDING_OFFSET+2)

#ifndef MAX_DAG_DEPTH
#define MAX_DAG_DEPTH (16)
#endif

#ifndef LOD_CUTOFF_CONSTANT
#define LOD_CUTOFF_CONSTANT (0.002)
#endif

#define MIN_VOXEL_SIZE (1.0 / pow(2, MAX_DAG_DEPTH))

#define MAX_DIST 1e9

#define AXIS_X_MASK 1
#define AXIS_Y_MASK 2
#define AXIS_Z_MASK 4

const uvec3 AXIS_MASK_VEC = uvec3(AXIS_X_MASK, AXIS_Y_MASK, AXIS_Z_MASK);

#define INCIDENCE_X 0
#define INCIDENCE_Y 1
#define INCIDENCE_Z 2

struct VChildDescriptor {
    // if a sub-DAG: positive 1-index pointers to children
    // if a leaf: negative voxel material id
    // if empty: 0
    int sub_voxels[8];
};

layout(binding = VOXEL_BINDING_OFFSET) buffer VoxelChildData {
    VChildDescriptor voxels[];
};
layout(binding = VOXEL_BINDING_OFFSET + 1) buffer VoxelMaterialData {
    uint lod_materials[];
};


uint idot(uvec3 a, uvec3 b) {
    return uint(dot(a,b));
}

vec2 project_cube(vec3 id, vec3 od, vec3 mn, vec3 mx, out uint incidence_min, out uint incidence_max) {

    vec3 tmn = fma(id, mn, od);
    vec3 tmx = fma(id, mx, od);


/*
    float ts;
    if (tmn.x > tmn.z) {
        incidence_min = INCIDENCE_X;
        ts = tmn.x;
    } else {
        incidence_min = INCIDENCE_Z;
        ts = tmn.z;
    }

    if (tmn.y > ts) {
        incidence_min = INCIDENCE_Y;
        ts = tmn.y;
    }

    float te;
    
    if (tmx.x < tmx.z) {
        incidence_max = INCIDENCE_X;
        te = tmx.x;
    } else {
        incidence_max = INCIDENCE_Z;
        te = tmx.z;
    }

    if (tmx.y < te) {
        incidence_max = INCIDENCE_Y;
        te = tmx.y;
    }

/*/


    float ts = max(tmn.x, max(tmn.y, tmn.z));

    float te = min(tmx.x, min(tmx.y, tmx.z));
    
    // if (tmx.x < tmx.z) {
    //     incidence_max = INCIDENCE_X;
    //     te = tmx.x;
    // } else {
    //     incidence_max = INCIDENCE_Z;
    //     te = tmx.z;
    // }

    // if (tmx.y < te) {
    //     incidence_max = INCIDENCE_Y;
    //     te = tmx.y;
    // }

    
    if (te == tmx.x) {incidence_max = INCIDENCE_X;}
    if (te == tmx.y) {incidence_max = INCIDENCE_Y;}
    if (te == tmx.z) {incidence_max = INCIDENCE_Z;}

// */
    

    return vec2(ts, te);
}


#define CONTOUR_MASK (4096-1)
#define CONTOUR_NUM_NORMALS 25
#define CONTOUR_NUM_OFFSETS 136
#define CONTOUR_NUM (CONTOUR_NUM_NORMALS * CONTOUR_NUM_OFFSETS)

// LUTs are generated using a Mathematica notebook in ./data
const vec3 contour_lut_normals[CONTOUR_NUM_NORMALS] = {
    { 0.5000,  0.5000,  0.5000},  {0.5000,  0.5000,  0.5000},  {0.5000,  0.5000,  0.5000},  { 0.5000,  0.5000,  0.5000},  { 0.5000,  0.5000,  0.0000},
    { 0.0000,  0.5000,  0.5000},  {0.0000,  0.5000, -0.5000},  {0.5000,  0.0000,  0.5000},  { 0.5000,  0.0000, -0.5000},  { 0.5000,  0.5000,  0.0000},
    { 0.5000, -0.5000,  0.0000},  {0.5000,  0.0000,  0.0000},  {0.0000,  0.5000,  0.0000},  { 0.0000,  0.0000,  0.5000},  { 0.5000,  0.1930, -0.3143},
    {-0.3143,  0.5000, -0.1930},  {0.1930,  0.3143,  0.5000},  {0.5000,  0.1930,  0.3143},  {-0.3143,  0.5000,  0.1930},  {-0.1930, -0.3143,  0.5000},
    { 0.5000, -0.1930, -0.3143},  {0.3143,  0.5000,  0.1930},  {0.1930, -0.3143,  0.5000},  { 0.5000, -0.1930,  0.3143},  { 0.3143,  0.5000, -0.1930}
};

const vec2 contour_lut_offsets[CONTOUR_NUM_OFFSETS] = {
    vec2(-0.5000, -0.4375),  vec2(-0.5000, -0.3750),  vec2(-0.5000, -0.3125),  vec2(-0.5000, -0.2500),  vec2(-0.5000, -0.1875),  vec2(-0.5000, -0.1250),  vec2(-0.5000, -0.0625),  vec2(-0.5000,  0.0000),
    vec2(-0.5000,  0.0625),  vec2(-0.5000,  0.1250),  vec2(-0.5000,  0.1875),  vec2(-0.5000,  0.2500),  vec2(-0.5000,  0.3125),  vec2(-0.5000,  0.3750),  vec2(-0.5000,  0.4375),  vec2(-0.5000,  0.5000),
    vec2(-0.4375, -0.3750),  vec2(-0.4375, -0.3125),  vec2(-0.4375, -0.2500),  vec2(-0.4375, -0.1875),  vec2(-0.4375, -0.1250),  vec2(-0.4375, -0.0625),  vec2(-0.4375,  0.0000),  vec2(-0.4375,  0.0625),
    vec2(-0.4375,  0.1250),  vec2(-0.4375,  0.1875),  vec2(-0.4375,  0.2500),  vec2(-0.4375,  0.3125),  vec2(-0.4375,  0.3750),  vec2(-0.4375,  0.4375),  vec2(-0.4375,  0.5000),  vec2(-0.3750, -0.3125),
    vec2(-0.3750, -0.2500),  vec2(-0.3750, -0.1875),  vec2(-0.3750, -0.1250),  vec2(-0.3750, -0.0625),  vec2(-0.3750,  0.0000),  vec2(-0.3750,  0.0625),  vec2(-0.3750,  0.1250),  vec2(-0.3750,  0.1875),
    vec2(-0.3750,  0.2500),  vec2(-0.3750,  0.3125),  vec2(-0.3750,  0.3750),  vec2(-0.3750,  0.4375),  vec2(-0.3750,  0.5000),  vec2(-0.3125, -0.2500),  vec2(-0.3125, -0.1875),  vec2(-0.3125, -0.1250),
    vec2(-0.3125, -0.0625),  vec2(-0.3125,  0.0000),  vec2(-0.3125,  0.0625),  vec2(-0.3125,  0.1250),  vec2(-0.3125,  0.1875),  vec2(-0.3125,  0.2500),  vec2(-0.3125,  0.3125),  vec2(-0.3125,  0.3750),
    vec2(-0.3125,  0.4375),  vec2(-0.3125,  0.5000),  vec2(-0.2500, -0.1875),  vec2(-0.2500, -0.1250),  vec2(-0.2500, -0.0625),  vec2(-0.2500,  0.0000),  vec2(-0.2500,  0.0625),  vec2(-0.2500,  0.1250),
    vec2(-0.2500,  0.1875),  vec2(-0.2500,  0.2500),  vec2(-0.2500,  0.3125),  vec2(-0.2500,  0.3750),  vec2(-0.2500,  0.4375),  vec2(-0.2500,  0.5000),  vec2(-0.1875, -0.1250),  vec2(-0.1875, -0.0625),
    vec2(-0.1875,  0.0000),  vec2(-0.1875,  0.0625),  vec2(-0.1875,  0.1250),  vec2(-0.1875,  0.1875),  vec2(-0.1875,  0.2500),  vec2(-0.1875,  0.3125),  vec2(-0.1875,  0.3750),  vec2(-0.1875,  0.4375),
    vec2(-0.1875,  0.5000),  vec2(-0.1250, -0.0625),  vec2(-0.1250,  0.0000),  vec2(-0.1250,  0.0625),  vec2(-0.1250,  0.1250),  vec2(-0.1250,  0.1875),  vec2(-0.1250,  0.2500),  vec2(-0.1250,  0.3125),
    vec2(-0.1250,  0.3750),  vec2(-0.1250,  0.4375),  vec2(-0.1250,  0.5000),  vec2(-0.0625,  0.0000),  vec2(-0.0625,  0.0625),  vec2(-0.0625,  0.1250),  vec2(-0.0625,  0.1875),  vec2(-0.0625,  0.2500),
    vec2(-0.0625,  0.3125),  vec2(-0.0625,  0.3750),  vec2(-0.0625,  0.4375),  vec2(-0.0625,  0.5000),  vec2( 0.0000,  0.0625),  vec2( 0.0000,  0.1250),  vec2( 0.0000,  0.1875),  vec2( 0.0000,  0.2500),
    vec2( 0.0000,  0.3125),  vec2( 0.0000,  0.3750),  vec2( 0.0000,  0.4375),  vec2( 0.0000,  0.5000),  vec2( 0.0625,  0.1250),  vec2( 0.0625,  0.1875),  vec2( 0.0625,  0.2500),  vec2( 0.0625,  0.3125),
    vec2( 0.0625,  0.3750),  vec2( 0.0625,  0.4375),  vec2( 0.0625,  0.5000),  vec2( 0.1250,  0.1875),  vec2( 0.1250,  0.2500),  vec2( 0.1250,  0.3125),  vec2( 0.1250,  0.3750),  vec2( 0.1250,  0.4375),
    vec2( 0.1250,  0.5000),  vec2( 0.1875,  0.2500),  vec2( 0.1875,  0.3125),  vec2( 0.1875,  0.3750),  vec2( 0.1875,  0.4375),  vec2( 0.1875,  0.5000),  vec2( 0.2500,  0.3125),  vec2( 0.2500,  0.3750),
    vec2( 0.2500,  0.4375),  vec2( 0.2500,  0.5000),  vec2( 0.3125,  0.3750),  vec2( 0.3125,  0.4375),  vec2( 0.3125,  0.5000),  vec2( 0.3750,  0.4375),  vec2( 0.3750,  0.5000),  vec2( 0.4375,  0.5000)
};

// project a contour onto a ray
// contours are described by in index in the range [0,3600) (or else the voxel does not have a contour)
// divided into two independent tables [0,30)x[0,120)
// rays are described by an origin and direction
vec2 project_contour(uint contour, vec3 o, vec3 d) {
    vec3 cnorm = contour_lut_normals[contour % CONTOUR_NUM_NORMALS];
    vec2 coffs = contour_lut_offsets[contour / CONTOUR_NUM_NORMALS];

    // what happens when this overflows?
    float v0 = 1.0 / dot(cnorm, d);
    float v1 = dot(o, cnorm);
    float v2 = (coffs.x - v1) * v0;
    float v3 = (coffs.y - v1) * v0;

    // not sure if this is faster or vec2(min(c,d), max(c,d))
    if (v2 < v3) {
        return vec2(v2,v3);
    } else {
        return vec2(v2,v3);
    }
}

bool voxel_valid_bit(uint parent, uint idx) {
    return voxels[parent].sub_voxels[idx] != 0;
}

#define SUBVOXEL_VALID(sv) (sv != 0)

bool voxel_leaf_bit(uint parent, uint idx) {
    return voxels[parent].sub_voxels[idx] < 0;
}

#define SUBVOXEL_LEAF(sv) (sv < 0)

bool voxel_empty(uint parent, uint idx) {
    return voxels[parent].sub_voxels[idx] == 0;
}

#define SUBVOXEL_EMPTY(sv) (sv != 0)

uint voxel_get_child(uint parent, uint idx) {
    return voxels[parent].sub_voxels[idx] - 1;
}

#define SUBVOXEL_CHILD(sv) (sv - 1)

int voxel_get_subvoxel(uint parent, uint idx) {
    return voxels[parent].sub_voxels[idx];
}

uint voxel_get_material(uint parent, uint idx) {
    return -voxels[parent].sub_voxels[idx];
}

#define SUBVOXEL_MATERIAL(sv) (-sv)

bool interval_nonempty(vec2 t) {
    return t.x < t.y;
}
vec2 interval_intersect(vec2 a, vec2 b) {
    return vec2(max(a.x,b.x), min(a.y, b.y));
    // return ((b.x > a.y || a.x > b.y) ? vec2(1,0) : vec2(max(a.x,b.x), min(a.y, b.y)));
}

uint select_child(vec3 pos, float scale, vec3 o, vec3 d, float t) {
    vec3 p = fma(d, vec3(t), o) - pos - scale;
    // vec3 p = o + d * t - pos - scale;

    uvec3 less = uvec3(lessThan(p, vec3(0)));

    uint idx = 0;

    // idx |= p.x < 0 ? 0 : AXIS_X_MASK;
    // idx |= p.y < 0 ? 0 : AXIS_Y_MASK;
    // idx |= p.z < 0 ? 0 : AXIS_Z_MASK;

    idx = idot(less, AXIS_MASK_VEC);

    return idx;
}

uint select_child_bit(vec3 pos, float scale, vec3 o, vec3 d, float t) {
    vec3 p = fma(d, vec3(t), o) - pos - scale;

    uvec3 s = uvec3(greaterThan(p, vec3(0)));
    // uvec3 s = uvec3(uint(p.x > 0), uint(p.y > 0), uint(p.z > 0));
    
    // return AXIS_X_MASK * s.x + AXIS_Y_MASK * s.y + AXIS_Z_MASK * s.z;
    return idot(s, AXIS_MASK_VEC);
}

uvec3 child_cube( uvec3 pos, uint scale, uint idx) {

    uvec3 offset = uvec3(
        bitfieldExtract(idx, 0, 1),
        bitfieldExtract(idx, 1, 1),
        bitfieldExtract(idx, 2, 1)
    );

    return pos + (scale * offset);
}

uint highest_differing_bit(uvec3 a, uvec3 b) {
    uvec3 t = a ^ b;

    return findMSB(t.x | t.y | t.z);
}

uint extract_child_slot(uvec3 pos, uint scale) {

    uvec3 d = uvec3(equal(pos & scale, uvec3(0)));

    // uint idx = 0;

    // idx |= (d.x == 0) ? 0 : AXIS_X_MASK;
    // idx |= (d.y == 0) ? 0 : AXIS_Y_MASK;
    // idx |= (d.z == 0) ? 0 : AXIS_Z_MASK;

    uint idx = idot(d, AXIS_MASK_VEC);

    return idx;
}

uint extract_child_slot_bfe(uvec3 pos, uint depth) {

    uvec3 d = bitfieldExtract(pos, int(depth), 1);

    // return AXIS_X_MASK * d.x + AXIS_Y_MASK * d.y + AXIS_Z_MASK * d.z;
    return idot(d, AXIS_MASK_VEC);
}

#define VOXEL_MARCH_MISS 0
#define VOXEL_MARCH_HIT 1
#define VOXEL_MARCH_MAX_DEPTH 2
#define VOXEL_MARCH_LOD 3
#define VOXEL_MARCH_MAX_DIST 4
#define VOXEL_MARCH_ERROR 5
#define VOXEL_MARCH_LOOP_END 6

bool voxel_march(vec3 o, vec3 d, uint max_depth, float max_dist, out float dist, out uint incidence, out uint vid, out uint material, out uint return_state, out uint iterations) {

    const uint MAX_SCALE = (1<<MAX_DAG_DEPTH);

    uint pstack[MAX_DAG_DEPTH];
    float tstack[MAX_DAG_DEPTH];
    uint dmask = 0;

    vec3 ds = sign(d);

    d *= ds;
    // o = o * ds + (1 - ds) * 0.5;
    o = fma(o, ds, (1 - ds) * 0.5);

    o *= MAX_SCALE;
    d *= MAX_SCALE;

    dmask |= ds.x < 0 ? AXIS_X_MASK : 0;
    dmask |= ds.y < 0 ? AXIS_Y_MASK : 0;
    dmask |= ds.z < 0 ? AXIS_Z_MASK : 0;

    float min_size = 0.00001;

    vec3 id = 1.0 / d;
    vec3 od = - o * id;

    max_dist *= MAX_SCALE;

    vec2 t = vec2(0, max_dist);

    float h = t.y;

    // fix initial position
    uvec3 pos = ivec3(0);
    uvec3 old_pos = pos;

    uint parent = 0;
    uint idx = 0;

    uint scale = 1 << MAX_DAG_DEPTH;
    uint depth = 1;

    uint incidence_min;

    vec2 tp = project_cube(id, od, pos, pos + scale, incidence_min, incidence);

    t = interval_intersect(t, tp);

    iterations = 0;

    if (!interval_nonempty(t)) {
        // we didn't hit the bounding cube
        return_state = VOXEL_MARCH_MISS;
        dist = tp.x;
        return false;
    }

    scale = scale >> 1;
    // idx = select_child(pos, scale, o, d, t.x);
    idx = select_child_bit(pos, scale, o, d, t.x);
    pos = child_cube(pos, scale, idx);

    return_state = VOXEL_MARCH_MISS;

    pstack[0] = parent;
    tstack[0] = t.y;
    vec2 tc, tv;

    // very hot loop
    while (iterations < 1024) {
        iterations += 1;

        uint new_incidence;

        tc = project_cube(id, od, pos, pos + scale, incidence_min, new_incidence);

        int subvoxel = voxel_get_subvoxel(parent, dmask ^ idx);

        if (SUBVOXEL_VALID(subvoxel) && interval_nonempty(t)) {

            if (scale <= tc.x * LOD_CUTOFF_CONSTANT || depth >= max_depth) {

                // voxel is too small
                dist = t.x;
                return_state = depth >= max_depth ? VOXEL_MARCH_MAX_DEPTH : VOXEL_MARCH_LOD;
                material = lod_materials[parent];
                return true;
            }

            if (tc.x > max_dist) {
                // voxel is beyond the render distance
                return_state = VOXEL_MARCH_MAX_DIST;
                return false;
            }

            tv = interval_intersect(tc, t);

            if (interval_nonempty(tv)) {
                if (SUBVOXEL_LEAF(subvoxel)) {
                    dist = tv.x;
                    vid = (parent << 3) | (dmask ^ idx);
                    return_state = VOXEL_MARCH_HIT;
                    material = SUBVOXEL_MATERIAL(subvoxel);
                    return true;
                }
                // descend:
                if (tc.y < h) {
                    pstack[depth] = parent;
                    tstack[depth] = t.y;
                }
                depth += 1;

                h = tc.y;
                scale = scale >> 1;
                parent = SUBVOXEL_CHILD(subvoxel);
                // idx = select_child(pos, scale, o, d, tv.x);
                idx = select_child_bit(pos, scale, o, d, tv.x);
                t = tv;
                pos = child_cube(pos, scale, idx);

                continue;
            }
        }

        incidence = new_incidence;

        // advance
        t.x = tc.y;

        uint mask = 0;
        uint bit_diff = 0;

        // switch (incidence) {
        // case INCIDENCE_X:
        //     uint px = pos.x;
        //     pos.x += scale;
        //     bit_diff = px ^ pos.x;
        //     // mask = AXIS_X_MASK;
        //     break;
        // case INCIDENCE_Y:
        //     uint py = pos.y;
        //     pos.y += scale;
        //     bit_diff = py ^ pos.y;
        //     // mask = AXIS_Y_MASK;
        //     break;
        // case INCIDENCE_Z:
        //     uint pz = pos.z;
        //     pos.z += scale;
        //     bit_diff = pz ^ pos.z;
        //     // mask = AXIS_Z_MASK;
        //     break;
        // }

        uvec3 incidence_mask = uvec3(incidence == INCIDENCE_X, incidence == INCIDENCE_Y, incidence == INCIDENCE_Z);

        uvec3 p = pos;
        bit_diff = idot((pos + scale) ^ pos, incidence_mask);
        pos += scale * incidence_mask;

        // bit_diff = p.x | p.y | p.z;

        mask = (1 << incidence);
        idx ^= mask;

        // idx bits should only ever flip 0->1 because we force the ray direction to always be in the (1,1,1) quadrant
        if ((idx & mask) == 0) {
            // ascend

            // highest differing bit
            // depth = ilog2(bit_diff);
            uint idepth = findMSB(bit_diff);

            // check if we exited voxel tree
            if (idepth >= MAX_DAG_DEPTH) {
                return_state = VOXEL_MARCH_MISS;
                return false;
            }

            depth = MAX_DAG_DEPTH - idepth;

            scale = MAX_SCALE >> depth;
            // scale = 1 << (MAX_DAG_DEPTH - 1 - depth);

            parent = pstack[depth];
            t.y = tstack[depth];

            // round position to correct voxel (mask out low bits)
            // pos &= 0xFFFFFFFF ^ (scale - 1);
            pos = bitfieldInsert(pos, uvec3(0), 0, int(idepth));
            
            // get the idx of the child at the new depth
            // idx = extract_child_slot(pos, scale);
            idx = extract_child_slot_bfe(pos, idepth);

            h = 0;
        }

    }


    return_state = VOXEL_MARCH_LOOP_END;
    return false;
}
***VERTEX SHADER***
#version 420

uniform float time;
uniform vec2 resolution;
uniform vec2 mouse;
uniform vec3 spectrum;
uniform mat4 mvp;

uniform vec3 pp = vec3(0.4, 380, 720);
uniform vec3 pp2 = vec3(1.0, 670, 560);

in vec4 a_position;
in vec3 a_normal;
in vec2 a_texcoord;
uniform float w;

uniform vec3 p1;
uniform vec3 p2;
uniform vec3 p3;
uniform vec3 p4;

int n;
int f;
int r;
int t;

struct Tri{
    vec4 p1;
    vec4 p2;
    vec4 p3;
    vec4[3] ps;
} Tr;

out VertexData
{
    vec4 v_position;
    vec3 v_normal;
    vec2 v_texcoord;
    Tri[4] triangles;
} outData;

Tri triangle(vec3 c1, vec3 c2, vec3 c3)
{   vec4[3] p = {vec4(c1, 1), vec4(c2, 1), vec4(c3, 1)};
    Tr = Tri(vec4(c1, 1), vec4(c2, 1), vec4(c3, 1), p);
    return Tr;
}

void set_frustum(int nn, int ff, int rr, int tt)
{
    n = nn;
    f = ff;
    r = rr;
    t = tt;
}

mat4 project_matrix()
{
    float zz = -(f + n) / (f - n);
    float ww = -2 * f * n / (f - n);
    vec4 xn = vec4(n/r,0,0,0);
    vec4 yn = vec4(0,n/t,0,0);
    vec4 zn = vec4(0,0,zz,-1);
    vec4 wn = vec4(0,0,ww,0);
    
    mat4 proj = mat4(xn, yn, zn, wn);
    return proj;
}

vec3 project_to_screen(mat4 pmat)
{
    vec2 uv = a_texcoord;
    vec4 clip = pmat * vec4(uv, uv.y, 1.0);
    float ww = clip.w;
    vec3 ndc = vec3(clip.x / ww, clip.y / ww, clip.z / ww);
    
    float resx = resolution.x/2;
    float resy = resolution.y/2;
    float zw = (f - n) / 2 * ndc.z + ((f + n) / 2);
    
    return ndc;
    //return vec3(ndc.x * resx + resx, ndc.y * resy + resy, zw);
}

Tri t1 = triangle(p3, p1, p4);
Tri t2 = triangle(pp, p1, p3);
Tri t3 = triangle(pp, p4, p1);
Tri t4 = triangle(p3, p4, pp2);

void main(void)
{

    Tri[] tr = {t1, t2, t3, t4};
    
    // Some drivers don't like position being written here
    // with the tessellation stages enabled also.
    // Comment next line when Tess.Eval shader is enabled.
    gl_Position = mvp * a_position;
    
    set_frustum(0, 20, 320, 246); 
    
    vec3 projection = project_to_screen(project_matrix());

    outData.v_position = a_position;
    outData.v_normal = a_normal;
    outData.v_texcoord = vec2(a_texcoord.x, a_texcoord.y);
    outData.triangles = tr;
}

***FRAGMENT SHADER***
#version 420

#define WIRE 0
#define THICK 0.0003

#define XROT 1
#define YROT 1

uniform float time;
uniform vec2 resolution;
uniform vec2 mouse;
uniform vec3 spectrum;
uniform mat2 m;
vec3 lightdir = vec3(m[0][0], m[0][1], m[1][0]);

uniform sampler2D texture0;
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform sampler2D texture3;
uniform sampler2D prevFrame;
uniform sampler2D prevPass;

uniform float horizon;
uniform ivec4 fr;
uniform vec3 cam;
uniform vec3 look;

uniform vec2 rot;

uniform vec3 p1;
uniform vec3 p2;
uniform vec3 p3;
uniform vec3 p4;

float n;
float f;
float r;
float t;

struct Tri{
    vec4 p1;
    vec4 p2;
    vec4 p3;
    vec4[3] ps;
    } Tr;

in VertexData
{
    vec4 v_position;
    vec3 v_normal;
    vec2 v_texcoord;
    Tri[4] triangles;
} inData;

out vec4 fragColor;

vec2 uv = vec2(inData.v_texcoord.x, 1 - inData.v_texcoord.y);

struct Quad{
    vec4 p1;
    vec4 p2;
    vec4 p3;
    vec4 p4;
    float dx;
    float dy;
    float dz;
    } Tex;
    


void set_frustum()
{
    n = fr.w;
    f = fr.z;
    r = float(fr.x) / 100;
    t = fr.y;
}

Quad make_quad(vec4 c1, vec4 c2, vec4 c3, vec4 c4)
{
    Tex = Quad(c1, c2, c3, c4,
    abs(c3.x - c1.x), abs(c3.y - c1.y), abs(c3.z - c1.z));
    return Tex;
}

Tri triangle(vec3 c1, vec3 c2, vec3 c3)
{   vec4[3] p = {vec4(c1, 1), vec4(c2, 1), vec4(c3, 1)};
    Tr = Tri(vec4(c1, 1), vec4(c2, 1), vec4(c3, 1), p);
    return Tr;
}

mat4 project_matrix()
{
    float zz = (f + n) / (f - n);
    float ww = -2 * f * n / (f - n);
    
    mat4 proj = mat4(n/r, 0, 0, 0,
                     0, n/t, 0, 0,
                     0, 0, zz, -1,
                     0, 0, ww, 0);
    return proj;
}

mat4 cam_matrix()
{
    float theta = (mouse.x * XROT * 2 - 1)/-100;
    float phi = -mouse.y * YROT * 2 + 1;
    
    //This matrix is the result of multiplying
    //translation matrix by x-axis rot by y-axis rot
    float sasb = -sin(theta) * sin(phi);
    float sacb = -sin(theta) * cos(phi);
    float casb = -cos(theta) * sin(phi);
    float cacb = -cos(theta) * cos(phi);
    mat4 cam = mat4(cos(theta), sasb, sacb, cam.x,
                    0, cos(phi), -sin(phi), -cam.y,
                    -sin(theta), casb, cacb ,cam.z,
                    0,0,0,1);

return transpose(cam);
}

vec3 project_to_screen(vec4 pos)
{
    //Get clipping coords
    mat4 pmat = project_matrix();
    vec4 proj = pmat * pos;
    //Get normalized screen coords
    vec3 corr = proj.xyz / proj.www;
    return (corr + 1) / 2;
}

vec3[3] project_tri(Tri t)
{
    //Each vertex is given in world space,
    //so we fully convert to screen space
    mat4 cam = cam_matrix();
    vec4[3] p = t.ps;
    vec3[3] pp = {
    vec3(project_to_screen(cam * p[0])),
    vec3(project_to_screen(cam * p[1])), 
    vec3(project_to_screen(cam * p[2]))};
    
    return pp;
}

vec4 project_to_world(mat4 pmat, vec3 pos)
{
    mat4 mati = inverse(pmat);
    vec3 pos2 = (pos * 2) - 1;
    vec4 corr = vec4((pos2.xyz), 1);
    return mati * corr;
}

int orientation(vec2 a, vec2 b, vec2 x)
{
    //Standard form of line
    float dx = b.x - a.x;
    float dy = b.y - a.y;
    return int(sign(dx*x.y - dy*x.x + a.x*b.y - b.x*a.y));
}

float interpoline(vec2 a, vec2 b, vec2 uv)
{
    float dx = b.x - a.x;
    float dy = b.y - a.y;
    
    return abs(dx*uv.y - dy*uv.x + a.x*b.y - b.x*a.y);
}

vec3 interp_quad(Quad q, vec3 pos)
{
    float xx = (pos.x - q.p1.x) / q.dx;
    float yy = (pos.y - q.p1.y) / q.dy;
    float zz = (q.p1.z - pos.z) / q.dz;
    return vec3(xx, yy, zz);
}

float tri_depth(vec2 p, vec3[3] tps)
{
    return 0;
}

vec3 draw_triangle(Tri t, vec3 col)
{
    vec3[3] p = project_tri(t);

    //For each pair of lines going CCW
    for (int i = 0; i < p.length(); i++)
    {
        int prev;
        
        if(i == 0)
        {
            prev = p.length() - 1;
        }
        else
        {
            prev = i - 1;
        }
        
        //If the orientation is always within the triangle,
        //draw the pixel
        if((orientation(p[1].xy, p[0].xy, uv) > 0) &&
        (orientation(p[2].xy, p[1].xy, uv) > 0) &&
        (orientation(p[0].xy, p[2].xy, uv) > 0))
        {
            return col;
        }
        
        vec2 a = p[i].xy;
        vec2 b = p[prev].xy;

        //Draw the line if wireframes are turned on and it's within the bounds
        //defined by the line
        if (WIRE != 0 && uv.x > min(a.x, b.x) && uv.x < max(a.x, b.x) &&
            uv.y > min(a.y, b.y) && uv.y < max(a.y, b.y))
            {
                float c = interpoline(a, b, uv);
                
                if(c <= THICK)
                {
                    c /= THICK;
                    return vec3(0,0,0);
                }
            }
    }
    return vec3(1,1,1);
}

vec3 get_point()
{
    Tri[4] ts = inData.triangles;

    Tri t = ts[0];
    Tri t2 = ts[1];
    Tri t3 = ts[2];
    Tri t4 = ts[3];
    
    vec3 tv = draw_triangle(t, vec3(0,1,0.4));
    vec3 t2v = draw_triangle(t2, vec3(1,0.1,0.5));
    vec3 t3v = draw_triangle(t3, vec3(0.1, 0, 0.8));
    vec3 t4v = draw_triangle(t4, vec3(0.5, 0.30, 0.1));
   
    if(tv != vec3(1,1,1))
    {
        return tv;
    }
    else if(t2v != vec3(1,1,1))
    {
        return t2v;
    }
    else if(t3v != vec3(1,1,1))
    {
        return t3v;
    }
   else
    {
        return t4v;
    }
}


void main(void)
{
    set_frustum();
 
    vec3 col = get_point();
    
    fragColor = vec4(col, 1.0);
}

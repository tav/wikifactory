// Public Domain (-) 2014 The Wikifactory Authors.
// See the Wikifactory UNLICENSE file for details.

package logo

import (
	"code.google.com/p/freetype-go/freetype/raster"
	"code.google.com/p/freetype-go/freetype/truetype"
	// "code.google.com/p/graphics-go/graphics"
	"errors"
	"image"
	"image/draw"
	"io/ioutil"
	"math/rand"
	"strings"
	"sync"
	"time"
)

const (
	dpi     = 300.0
	text    = "Wikifactory"
	width   = 1000
	height  = 128
	maxSize = 24
)

var InvalidSize = errors.New("logo: invalid size parameter")

var fontFiles = []string{
	"fonts/brandon-printed-one.ttf",
	"fonts/brandon-printed-two.ttf",
	"fonts/brandon-printed-double.ttf",
	// "fonts/brandon-printed-inline.ttf",
	// "fonts/brandon-printed-one-shadow.ttf",
}

var (
	fonts    = []*truetype.Font{}
	glyphset = [maxSize + 1][]*glyph{}
	mutex    = sync.RWMutex{}
	variants = len(fontFiles) * 2
)

var r = raster.NewRasterizer(0, 0)

func Render(size int, color *image.Uniform) (image.Image, error) {
	if size <= 0 || size > maxSize {
		return nil, InvalidSize
	}
	glyphs := getGlyphs(size)
	ctx := image.Rect(0, 0, width, height)
	img := image.NewRGBA(ctx)
	for i := 0; i < len(text); i++ {
		choice := (rand.Intn(variants) * len(text)) + i
		glyph := glyphs[choice]
		if i == 0 {
			draw.DrawMask(img, invertGlyph.dr, color, image.ZP, color, invertGlyph.mp, draw.Over)
			draw.DrawMask(img, invertGlyph.dr, image.White, image.ZP, invertGlyph.mask, invertGlyph.mp, draw.Over)
		} else {
			draw.DrawMask(img, glyph.dr, color, image.ZP, glyph.mask, glyph.mp, draw.Over)
		}
	}
	return img, nil
	// dst := image.NewRGBA(ctx)
	// err := graphics.Blur(dst, img, &graphics.BlurOptions{0.84, 0})
	// return dst, err
}

func loadFont(path string) (*truetype.Font, error) {
	file, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return truetype.Parse(file)
}

var (
	// invertFont = "fonts/brandon-grotesque-bold.ttf"
	invertFont  = "fonts/brandon-grotesque-black.ttf"
	invertGlyph *glyph
)

func Setup() error {
	rand.Seed(time.Now().UnixNano())
	for _, path := range fontFiles {
		font, err := loadFont(path)
		if err != nil {
			return err
		}
		fonts = append(fonts, font)
	}
	getGlyphs(24)
	font, err := loadFont(invertFont)
	if err != nil {
		return err
	}
	invertGlyph = genGlyphs(font, 24, "W")[0]
	return nil
}

type glyph struct {
	mask *image.Alpha
	mp   image.Point
	dr   image.Rectangle
}

func getGlyphs(size int) []*glyph {
	mutex.RLock()
	glyphs := glyphset[size]
	mutex.RUnlock()
	if glyphs != nil {
		return glyphs
	}
	mutex.Lock()
	defer mutex.Unlock()
	glyphs = []*glyph{}
	for _, font := range fonts {
		glyphs = append(glyphs, genGlyphs(font, size, text)...)
	}
	glyphset[size] = glyphs
	return glyphs
}

func Pt(x, y int) raster.Point {
	return raster.Point{
		X: raster.Fix32(x << 8),
		Y: raster.Fix32(y << 8),
	}
}

func pointToFix32(x float64) raster.Fix32 {
	return raster.Fix32(x * dpi * (256.0 / 72.0))
}

func drawContour(r *raster.Rasterizer, ps []truetype.Point, dx, dy raster.Fix32) {
	if len(ps) == 0 {
		return
	}
	// ps[0] is a truetype.Point measured in FUnits and positive Y going upwards.
	// start is the same thing measured in fixed point units and positive Y
	// going downwards, and offset by (dx, dy)
	start := raster.Point{
		X: dx + raster.Fix32(ps[0].X<<2),
		Y: dy - raster.Fix32(ps[0].Y<<2),
	}
	r.Start(start)
	q0, on0 := start, true
	for _, p := range ps[1:] {
		q := raster.Point{
			X: dx + raster.Fix32(p.X<<2),
			Y: dy - raster.Fix32(p.Y<<2),
		}
		on := p.Flags&0x01 != 0
		if on {
			if on0 {
				r.Add1(q)
			} else {
				r.Add2(q0, q)
			}
		} else {
			if on0 {
				// No-op.
			} else {
				mid := raster.Point{
					X: (q0.X + q.X) / 2,
					Y: (q0.Y + q.Y) / 2,
				}
				r.Add2(q0, mid)
			}
		}
		q0, on0 = q, on
	}
	// Close the curve.
	if on0 {
		r.Add1(start)
	} else {
		r.Add2(q0, start)
	}
}

func genGlyphs(font *truetype.Font, size int, text string) (glyphs []*glyph) {

	scale := int32(float64(size) * dpi * (64.0 / 72.0))
	clip := image.Rect(0, 0, width, height)

	// Calculate the rasterizer's bounds to handle the largest glyph.
	b := font.Bounds(scale)
	xmin := int(b.XMin) >> 6
	ymin := -int(b.YMax) >> 6
	xmax := int(b.XMax+63) >> 6
	ymax := -int(b.YMin-63) >> 6

	r := raster.NewRasterizer(xmax-xmin, ymax-ymin)
	buf := truetype.NewGlyphBuf()

	for _, variant := range []string{strings.ToUpper(text), strings.ToLower(text)} {

		pt := Pt(30, 10+int(pointToFix32(float64(size))>>8))

		for _, char := range variant {

			idx := font.Index(char)
			buf.Load(font, scale, idx, truetype.FullHinting)

			// Calculate the integer-pixel bounds for the glyph.
			xmin := int(raster.Fix32(buf.B.XMin<<2)) >> 8
			ymin := int(-raster.Fix32(buf.B.YMax<<2)) >> 8
			xmax := int(raster.Fix32(buf.B.XMax<<2)+0xff) >> 8
			ymax := int(-raster.Fix32(buf.B.YMin<<2)+0xff) >> 8
			fx := raster.Fix32(-xmin << 8)
			fy := raster.Fix32(-ymin << 8)

			ix := int(pt.X >> 8)
			iy := int(pt.Y >> 8)

			// Rasterize the glyph's vectors.
			r.Clear()
			e0 := 0
			for _, e1 := range buf.End {
				drawContour(r, buf.Point[e0:e1], fx, fy)
				e0 = e1
			}

			mask := image.NewAlpha(image.Rect(0, 0, xmax-xmin, ymax-ymin))
			r.Rasterize(raster.NewAlphaSrcPainter(mask))
			pt.X += raster.Fix32(buf.AdvanceWidth << 2)
			offset := image.Point{xmin + ix, ymin + iy}

			glyphRect := mask.Bounds().Add(offset)
			dr := clip.Intersect(glyphRect)
			mp := image.Point{0, dr.Min.Y - glyphRect.Min.Y}
			glyphs = append(glyphs, &glyph{
				mask: mask,
				mp:   mp,
				dr:   dr,
			})

		}
	}

	return

}

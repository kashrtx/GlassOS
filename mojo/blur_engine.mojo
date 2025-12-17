# GlassOS Blur Engine - High Performance Blur Calculations
# Optimized blur calculations for the Glass Aero theme

from memory import memset_zero
from math import exp, sqrt
from sys import sizeof

alias SIMD_WIDTH = 8

struct GaussianKernel:
    """Precomputed Gaussian kernel for blur operations."""
    
    var radius: Int
    var weights: List[Float32]
    var sigma: Float32
    
    fn __init__(inout self, radius: Int):
        self.radius = radius
        self.sigma = Float32(radius) / 3.0
        self.weights = List[Float32]()
        self._compute_weights()
    
    fn _compute_weights(inout self):
        """Compute Gaussian weights."""
        var sum: Float32 = 0.0
        var size = self.radius * 2 + 1
        
        for i in range(size):
            var x = Float32(i - self.radius)
            var weight = exp(-(x * x) / (2.0 * self.sigma * self.sigma))
            self.weights.append(weight)
            sum += weight
        
        # Normalize weights
        for i in range(len(self.weights)):
            self.weights[i] /= sum


struct BlurEngine:
    """High-performance blur calculations for Glass Aero effects."""
    
    var kernel: GaussianKernel
    
    fn __init__(inout self, radius: Int = 40):
        self.kernel = GaussianKernel(radius)
    
    fn blur_horizontal(self, 
                       input: List[Float32], 
                       width: Int, 
                       height: Int) -> List[Float32]:
        """Apply horizontal blur pass."""
        var output = List[Float32](capacity=len(input))
        
        for y in range(height):
            for x in range(width):
                var sum: Float32 = 0.0
                
                for k in range(-self.kernel.radius, self.kernel.radius + 1):
                    var sx = x + k
                    if sx >= 0 and sx < width:
                        var idx = y * width + sx
                        var weight_idx = k + self.kernel.radius
                        sum += input[idx] * self.kernel.weights[weight_idx]
                
                output.append(sum)
        
        return output
    
    fn blur_vertical(self,
                     input: List[Float32],
                     width: Int,
                     height: Int) -> List[Float32]:
        """Apply vertical blur pass."""
        var output = List[Float32](capacity=len(input))
        
        for y in range(height):
            for x in range(width):
                var sum: Float32 = 0.0
                
                for k in range(-self.kernel.radius, self.kernel.radius + 1):
                    var sy = y + k
                    if sy >= 0 and sy < height:
                        var idx = sy * width + x
                        var weight_idx = k + self.kernel.radius
                        sum += input[idx] * self.kernel.weights[weight_idx]
                
                output.append(sum)
        
        return output
    
    fn apply_blur(self,
                  input: List[Float32],
                  width: Int,
                  height: Int) -> List[Float32]:
        """Apply full Gaussian blur (horizontal + vertical passes)."""
        var horizontal = self.blur_horizontal(input, width, height)
        return self.blur_vertical(horizontal, width, height)


fn create_blur_engine(radius: Int = 40) -> BlurEngine:
    """Create a new blur engine instance."""
    return BlurEngine(radius)


fn calculate_glass_opacity(base_opacity: Float32, 
                           blur_amount: Float32,
                           tint_strength: Float32) -> Float32:
    """Calculate final glass opacity for the Aero effect."""
    var blur_factor = 1.0 - (blur_amount / 100.0) * 0.3
    var tint_factor = tint_strength * 0.2
    return base_opacity * blur_factor + tint_factor

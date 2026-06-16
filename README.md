# Axonal Damage Analysis

ImageJ macro for quantifying axonal bead formation as a readout of axonal damage
in drug screening experiments.

## Biological Background

Axonal beads (or spheroids) are swellings that form along neuronal axons under
stress conditions (e.g., glutamate excitotoxicity).

These beads can be identified on iPSC-derived neurons exposed to excessive
glutamate concentrations as accumulation of neurofilament staining (e.g., SMI-31).

This macro:
1. Measures total neurofilament-positive (SMI-31) neurite area
2. Counts axonal beads via intensity thresholding and particle analysis
3. Normalizes bead count per neurite area (beads / 1000 µm²)

This normalized metric serves as a robust, scalable readout for axonal damage in
high-content drug screening.

## Publication

This analysis pipeline was used in:

> Guerrero Gonzalez, E., et al. (2025). *Development of a Human Preclinical 
> Platform for the Identification of Neuroprotective Compounds.* 
> European Journal of Neuroscience, 62(10), e70328. 
> [https://doi.org/10.1111/ejn.70328](https://doi.org/10.1111/ejn.70328)

## Requirements:

- Fiji (ImageJ 1.54+)
- GDSC plugin suite (Difference of Gaussians)
 - Install: `Help > Update... > Manage Update Sites > Check 'GDSC'`
- Excel Functions plugin (for .xlsx export)
 - Install: `Help > Update... > Manage Update Sites > Check 'Excel Functions'`
- Restart Fiji after installing plugins

## Input

- CZI confocal images with **2 channels**:
 - C1: Blue (DAPI) - nuclear stain, not analyzed
 - C2: Green (SMI-31) - neurofilament, our channel of interest

## Usage

1. Open Fiji
2.`Plugins > Macros > Run...` and select `AxonalBeadAnalysis.ijm`
3. In the dialog:
   - Select your **input folder** containing `.czi`files
   - Set **DoG sigmas** (default: 5, 1).
   - Set **bead threshold** (test on a representative image first!)
   - Adjust **bead size** (default: 4-80 pixels) and **circularity** (default: 0.3-1.0)
   - Toggle **QC overlay images**
4. Click OK - the macro processes all `.czi`files recursively

## Output

For each input folder, an `Analysis\` folder is created containing:
| Parameter | Default | Description |
|-----------|---------|-------------|
| DoG sigma1 | 5 | Larger sigma for noise suppression |
| DoG sigma2 | 1 | Smaller sigma for filament preservation |
| Bead threshold | 200 | Manual 8-bit threshold for bead detection. **Must be pre-tested!** |
| Bead min size | 4 px | Minimum bead area |
| Bead max size | 80 px | Maximum bead area |
| Bead min circularity | 0.3 | Minimum roundness (0 = line, 1 = perfect circle) |
| Bead max circularity | 1.0 | Maximum roundness |

## Important Notes

- **Pre-test your bead threshold** Open a representative image, split channels,
  select green, and use `Image > Adjust > Threshold`
- The GDSC Difference of Gaussians plugin may log a harmless
  `NoClassDefFoundError`for UsageTracker. This is a known upstream issue and does
  not affect results.
- Neurite area measurement uses DoG + default mask conversion (no explicit threshold),
  matching the original published workflow.

## License

MIT License — see [LICENSE](LICENSE)

## Author

Ezra Guerrero González, PhD

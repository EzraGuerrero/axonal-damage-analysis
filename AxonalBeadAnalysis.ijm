/*
 * Axonal Damage Analysis: Axonal Beads / Neurofilament+ Area
 * 
 * Measures neurofilament-positive filament area and counts axonal beads
 * from CZI confocal images. Normalizes bead count per neurite area
 * as a readout for axonal damage in drug screening experiments.
 * 
 * Publication: European Journal of Neuroscience, 2025
 * DOI: 10.1111/ejn.70328
 * 
 * License: MIT
 * Copyright 2026, Ezra Guerrero Gonzalez, PhD
 */

/*
 * PREREQUISITES:
 * 1. GDSC plugin suite (Difference of Gaussians)
 *    Install: Help > Update... > Manage Update Sites > Check 'GDSC' > Apply changes
 * 2. Excel Functions plugin (for .xlsx export)
 *    Install: Help > Update... > Manage Update Sites > Check 'Excel Functions' > Apply changes
 * Restart Fiji after installing plugins.
 * 
 * 
 */

// ============================================
// SCIJAVA PARAMETER DIALOG
// ============================================

#@File (label="Input folder", style="directory") chosen_dir
#@Integer (label="DoG sigma1 (noise suppression)", min="1", max="20", value="5") dog_sigma1
#@Integer (label="DoG sigma2 (filament preservation)", min="1", max="10", value="1") dog_sigma2
#@Integer (label="Bead threshold (TEST FIRST! 0-255)", min="0", max="255", value="200") bead_manual_threshold
#@Integer (label="Bead min size (pixels)", min="1", max="500", value="4") bead_min_size_px
#@Integer (label="Bead max size (pixels)", min="1", max="1000", value="80") bead_max_size_px
#@Float (label="Bead min circularity", min="0.0", max="1.0", value="0.3") bead_min_circ
#@Float (label="Bead max circularity", min="0.0", max="1.0", value="1.0") bead_max_circ
#@Boolean (label="Save QC overlay images", value="true") save_overlays

chosen_dir += File.separator;

// ============================================
// FIJI SETUP
// ============================================

run("Set Measurements...", "area limit display redirect=None decimal=3");
setOption("BlackBackground", true);
setBatchMode(true);

// ============================================
// GLOBAL VARIABLES
// ============================================

var summary_table = "Summary_Results";
var output_dir_path = "";

// ============================================
// MAIN EXECUTION
// ============================================

Table.create(summary_table);
Table.setColumn("Filename", newArray(0));
Table.setColumn("Neurite_Area_um2", newArray(0));
Table.setColumn("Bead_Count", newArray(0));
Table.setColumn("Beads_per_1000um2", newArray(0));
Table.setColumn("Scale_um_per_pixel", newArray(0));

process_files(chosen_dir);

setBatchMode(false);

// ============================================
// FILE PROCESSOR (Recursive)
// ============================================

function process_files(input_dir) {
	
	file_list = getFileList(input_dir);
	
	// Output folder setup (auto-increment if exists)
	output_dir_name = input_dir + "Analysis";
	folder_count = 1;
	
	while (File.exists(output_dir_name)) {
		output_dir_name = input_dir + "analysis_" + folder_count;
		folder_count++;
	}
	
	output_dir_path = output_dir_name + File.separator;
	File.makeDirectory(output_dir_name);
	
	// Process files
	for (f = 0; f < file_list.length; f++) {
		
		if (endsWith(file_list[f], ".czi")) {
			
			// Open CZI via Bio-Formats
			run("Bio-Formats Importer", "open=[" + input_dir + file_list[f] + "] autoscale color_mode=Composite view=Hyperstack");
			results = axonal_damage(input_dir + file_list[f]);
			
			// Append to summary table
			row = Table.size(summary_table);
			Table.set("Filename", row, file_list[f], summary_table);
			Table.set("Neurite_Area_um2", row, results[0], summary_table);
			Table.set("Bead_Count", row, results[1], summary_table);
			Table.set("Beads_per_1000um2", row, results[2], summary_table);
			Table.set("Scale_um_per_pixel", row, results[3], summary_table);
			Table.update(summary_table);
			
		} else if (File.isDirectory(input_dir + file_list[f]) && !matches(file_list[f], ".*[A|a]nalysis.*")) {
			process_files(input_dir + file_list[f]);
		}
	}
	
	save_summary_table();
}

// ============================================
// ANALYSIS FUNCTION
// ============================================

function axonal_damage(file_path) {
	
	// IMAGE SETUP
	original_image = getTitle();
	getPixelSize(unit, pixelWidth, pixelHeight);
	scale_um_per_px = pixelWidth;
	
	run("Split Channels");
	blue = "C1-" + original_image;
	green = "C2-" + original_image;
	
	if (isOpen(blue)) { selectWindow(blue); close(); }
	selectWindow(green);
	green_id = getImageID();
	
	// NEURITE AREA
	run("Duplicate...", "title=neurite_temp");
	selectImage("neurite_temp");
	run("8-bit");
	run("Difference of Gaussians", "  sigma1=" + dog_sigma1 + " sigma2=" + dog_sigma2 + " enhance");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	wait(300); // (optional) allows user to briefly check image during batch processing
	run("Measure");
	neurite_area = getResult("Area", nResults - 1);
	run("Clear Results");
	
	// Save Neurite Mask Overlay
	if (save_overlays) {
		selectImage("neurite_temp");
		save(output_dir_path + "NeuriteMask_" + File.getNameWithoutExtension(file_path) + ".png");
		close("neurite_temp");
	}
	
	// BEAD COUNTING
	selectImage(green_id);
	run("Duplicate...", "title=bead_temp");
	selectImage("bead_temp");
	run("8-bit");
	setThreshold(bead_manual_threshold, 255);
	run("Convert to Mask");
	run("Analyze Particles...", "size=" + bead_min_size_px + "-" + bead_max_size_px + 
	    " circularity=" + bead_min_circ + "-" + bead_max_circ + 
	    " show=Outlines display exclude clear summarize");
	bead_count = nResults;
	
	// Save bead overlay
	if (save_overlays) {
		selectImage("Drawing of bead_temp");
		save(output_dir_path + "BeadOverlay_" + File.getNameWithoutExtension(file_path) + ".png");
		close("Drawing of bead_temp");
	}
	
	close("bead_temp");
	close(green);
	
	// NORMALIZATION
	beads_per_1000um2 = 0;
	if (neurite_area > 0) beads_per_1000um2 = (bead_count / neurite_area) * 1000;
	
	
	// RETURN RESULTS
	return newArray(
	neurite_area,
	bead_count,
	beads_per_1000um2,
	scale_um_per_px
	)
	
}

// ============================================
// SUMMARY EXPORT
// ============================================

function save_summary_table() {
	
	// CSV (universal compatibility)
	csv_path = output_dir_path + "Summary_Results.csv";
	Table.save(csv_path, summary_table);
	print("CSV saved: " + csv_path);
	
	// Excel (requires Excel Functions plugin)
	run("Excel Macro Extensions", "debuglogging=false");
	xlsx_path = output_dir_path + "Summary_Results.xlsx";
	
	// Check if file exists (e.g., from previous run)
	if (File.exists(xlsx_path)) {
		// Append to existing file
		Ext.xlsx_AppendTableAsRows(summary_table, xlsx_path, "Results", false);
		print("Excel appended: " + xlsx_path);
	} else {
		// First time: create new worksheet with headers
		Ext.xlsx_SaveTableAsWorksheet(summary_table, xlsx_path, "Results", true);
		print("Excel created: " + xlsx_path);
	}
}

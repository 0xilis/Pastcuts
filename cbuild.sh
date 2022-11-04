echo "Building Pastcuts..."
make clean
rm ./.DS_Store
rm ./pastcutsprefs/.DS_Store
rm ./pastcutsprefs/Resources/.DS_Store
rm ./pastcutsprefs/layout/.DS_Store
rm ./pastcutsprefs/layout/Library/.DS_Store
rm ./pastcutsprefs/layout/Library/PreferenceLoader/.DS_Store
rm ./pastcutsprefs/layout/Library/PreferenceLoader/Preferences/.DS_Store
echo "Cleaned and removed DS_Stores."
echo "Listing noisy files:"
find . -name .DS_Store -or -name Thumbs.db
echo "Done listing noisy files."
echo "Making Pastcuts..."
make package FINALPACKAGE=1
echo "Pastcuts build completed!"

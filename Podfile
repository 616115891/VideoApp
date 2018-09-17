platform :ios, '9.0'
use_frameworks!

def shared_pod
	pod 'CoreStore'
	pod 'SnapKit'
end

targetNameArray = [
"VideoApp",
]

targetNameArray.each do |targetName|
puts targetName + " Pod Installing..."
target :"#{targetName}" do
shared_pod
project 'VideoApp.xcodeproj'
end
end

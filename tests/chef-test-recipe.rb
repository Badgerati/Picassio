powershell_script 'Test Recipe Script' do
    code 'Write-Host "Hello, world!"'
    guard_interpreter :powershell_script
end

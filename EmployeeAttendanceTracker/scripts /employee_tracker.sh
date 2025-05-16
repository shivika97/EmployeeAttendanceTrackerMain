#!/bin/bash

# Employee Attendance Tracker
# Created: May 7, 2025
# Description: A shell script to track employee attendance using dialog boxes

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "Dialog is not installed. Please install dialog using:"
    echo "sudo apt-get install dialog"
    exit 1
fi

# Set up paths to data files
BASE_DIR=~/Desktop/EmployeeAttendanceTracker
DATA_DIR="$BASE_DIR/data"
EMPLOYEES_CSV="$DATA_DIR/employees.csv"
ATTENDANCE_CSV="$DATA_DIR/attendance.csv"

# Create necessary directories and files if they don't exist
mkdir -p "$DATA_DIR"

# Initialize employees.csv with header if it doesn't exist
if [ ! -f "$EMPLOYEES_CSV" ]; then
    echo "EmployeeID,Name,Department,JoiningDate" > "$EMPLOYEES_CSV"
fi

# Initialize attendance.csv with header if it doesn't exist
if [ ! -f "$ATTENDANCE_CSV" ]; then
    echo "Date,EmployeeID,Status" > "$ATTENDANCE_CSV"
fi

# Function to generate a unique employee ID
generate_employee_id() {
    if [ ! -f "$EMPLOYEES_CSV" ] || [ $(wc -l < "$EMPLOYEES_CSV") -eq 1 ]; then
        echo "EMP1001"
    else
        last_id=$(tail -n 1 "$EMPLOYEES_CSV" | cut -d ',' -f 1 | tr -d 'EMP')
        next_id=$((last_id + 1))
        echo "EMP$next_id"
    fi
}

# Function to check if employee exists
employee_exists() {
    local emp_id="$1"
    grep -q "^$emp_id," "$EMPLOYEES_CSV"
    return $?
}

# Function to validate date format (YYYY-MM-DD)
validate_date() {
    local date_input="$1"
    if [[ "$date_input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to add a new employee
add_employee() {
    # Use dialog to get employee details
    tempfile=$(mktemp)
    
    dialog --title "Add New Employee" \
           --form "Enter Employee Details:" 15 60 3 \
           "Name:" 1 1 "" 1 20 30 0 \
           "Department:" 2 1 "" 2 20 30 0 \
           "Joining Date (YYYY-MM-DD):" 3 1 "" 3 20 30 0 \
           2> "$tempfile"
    
    if [ $? -ne 0 ]; then
        rm -f "$tempfile"
        return
    fi
    
    # Read form values
    name=$(sed -n '1p' "$tempfile")
    department=$(sed -n '2p' "$tempfile")
    joining_date=$(sed -n '3p' "$tempfile")
    
    # Validate inputs
    if [ -z "$name" ] || [ -z "$department" ] || [ -z "$joining_date" ]; then
        dialog --title "Error" --msgbox "All fields are required!" 8 40
        rm -f "$tempfile"
        return
    fi
    
    # Validate date format
    if ! validate_date "$joining_date"; then
        dialog --title "Error" --msgbox "Invalid date format. Please use YYYY-MM-DD." 8 50
        rm -f "$tempfile"
        return
    fi
    
    # Generate employee ID
    emp_id=$(generate_employee_id)
    
    # Add employee to CSV
    echo "$emp_id,$name,$department,$joining_date" >> "$EMPLOYEES_CSV"
    
    dialog --title "Success" --msgbox "Employee added successfully!\nEmployee ID: $emp_id" 8 50
    
    rm -f "$tempfile"
}

# Function to update employee details
update_employee() {
    # First, let the user select an employee ID
    select_employee_id
    
    # Check if employee was selected
    if [ ! -f "/tmp/employee_id_selected.tmp" ]; then
        return
    fi
    
    emp_id=$(cat /tmp/employee_id_selected.tmp)
    rm -f /tmp/employee_id_selected.tmp
    
    if [ -z "$emp_id" ]; then
        return
    fi
    
    # Get current details of the employee
    employee_data=$(grep "^$emp_id," "$EMPLOYEES_CSV")
    current_name=$(echo "$employee_data" | cut -d ',' -f 2)
    current_dept=$(echo "$employee_data" | cut -d ',' -f 3)
    current_joining_date=$(echo "$employee_data" | cut -d ',' -f 4)
    
    # Use dialog to get updated details
    tempfile=$(mktemp)
    
    dialog --title "Update Employee" \
           --form "Update Employee Details for $emp_id:" 15 60 3 \
           "Name:" 1 1 "$current_name" 1 20 30 0 \
           "Department:" 2 1 "$current_dept" 2 20 30 0 \
           "Joining Date (YYYY-MM-DD):" 3 1 "$current_joining_date" 3 20 30 0 \
           2> "$tempfile"
    
    if [ $? -ne 0 ]; then
        rm -f "$tempfile"
        return
    fi
    
    # Read form values
    name=$(sed -n '1p' "$tempfile")
    department=$(sed -n '2p' "$tempfile")
    joining_date=$(sed -n '3p' "$tempfile")
    
    # Validate inputs
    if [ -z "$name" ] || [ -z "$department" ] || [ -z "$joining_date" ]; then
        dialog --title "Error" --msgbox "All fields are required!" 8 40
        rm -f "$tempfile"
        return
    fi
    
    # Validate date format
    if ! validate_date "$joining_date"; then
        dialog --title "Error" --msgbox "Invalid date format. Please use YYYY-MM-DD." 8 50
        rm -f "$tempfile"
        return
    fi
    
    # Update employee in CSV
    sed -i "s|^$emp_id,.*$|$emp_id,$name,$department,$joining_date|" "$EMPLOYEES_CSV"
    
    dialog --title "Success" --msgbox "Employee details updated successfully!" 8 50
    
    rm -f "$tempfile"
}

# Function to select an employee ID
select_employee_id() {
    # Check if there are employees
    if [ $(wc -l < "$EMPLOYEES_CSV") -eq 1 ]; then
        dialog --title "Error" --msgbox "No employees found in the database!" 8 40
        return 1
    fi
    
    # Create temporary files for dialog menu
    tempfile=$(mktemp)
    options_file=$(mktemp)
    
    # Create options for dialog menu from employees.csv
    tail -n +2 "$EMPLOYEES_CSV" | awk -F, '{print $1 " " $2 " (" $3 ")"}' > "$options_file"
    
    # Count number of options
    option_count=$(wc -l < "$options_file")
    
    # Display dialog menu for selecting employee
    dialog --title "Select Employee" \
           --menu "Choose an employee:" 20 60 $option_count \
           $(cat "$options_file") \
           2> "$tempfile"
    
    # Check if user canceled
    if [ $? -ne 0 ]; then
        rm -f "$tempfile" "$options_file"
        return 1
    fi
    
    # Extract selected employee ID
    selected_id=$(cat "$tempfile" | cut -d ' ' -f 1)
    echo "$selected_id" > /tmp/employee_id_selected.tmp
    
    rm -f "$tempfile" "$options_file"
    return 0
}

# Function to delete an employee
delete_employee() {
    # First, let the user select an employee ID
    select_employee_id
    
    # Check if employee was selected
    if [ ! -f "/tmp/employee_id_selected.tmp" ]; then
        return
    fi
    
    emp_id=$(cat /tmp/employee_id_selected.tmp)
    rm -f /tmp/employee_id_selected.tmp
    
    if [ -z "$emp_id" ]; then
        return
    fi
    
    # Ask for confirmation
    dialog --title "Confirm Deletion" \
           --yesno "Are you sure you want to delete employee $emp_id?" 8 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Delete employee from CSV
    sed -i "/^$emp_id,/d" "$EMPLOYEES_CSV"
    
    # Also delete their attendance records
    sed -i "/,$emp_id,/d" "$ATTENDANCE_CSV"
    
    dialog --title "Success" --msgbox "Employee and associated attendance records deleted successfully!" 8 60
}

# Function to view employee list
view_employee_list() {
    # Check if there are employees
    if [ $(wc -l < "$EMPLOYEES_CSV") -eq 1 ]; then
        dialog --title "Employee List" --msgbox "No employees found in the database!" 8 40
        return
    fi
    
    # Create a formatted display of employees
    tempfile=$(mktemp)
    
    echo "Employee List:" > "$tempfile"
    echo "----------------------------------" >> "$tempfile"
    echo "ID | Name | Department | Joining Date" >> "$tempfile"
    echo "----------------------------------" >> "$tempfile"
    
    tail -n +2 "$EMPLOYEES_CSV" | awk -F, '{printf "%-8s | %-15s | %-15s | %s\n", $1, $2, $3, $4}' >> "$tempfile"
    
    dialog --title "Employee List" --textbox "$tempfile" 20 80
    
    rm -f "$tempfile"
}

# Function to mark attendance
mark_attendance() {
    # Get today's date
    today=$(date +%Y-%m-%d)
    
    # First, let the user select an employee ID
    select_employee_id
    
    # Check if employee was selected
    if [ ! -f "/tmp/employee_id_selected.tmp" ]; then
        return
    fi
    
    emp_id=$(cat /tmp/employee_id_selected.tmp)
    rm -f /tmp/employee_id_selected.tmp
    
    if [ -z "$emp_id" ]; then
        return
    fi
    
    # Check if attendance is already marked for today
    if grep -q "^$today,$emp_id," "$ATTENDANCE_CSV"; then
        dialog --title "Error" --msgbox "Attendance for $emp_id already marked for today!" 8 60
        return
    fi
    
    # Ask for attendance status
    dialog --title "Mark Attendance" \
           --menu "Select attendance status for $emp_id:" 12 60 2 \
           "Present" "Mark as Present" \
           "Absent" "Mark as Absent" \
           2> /tmp/attendance_status.tmp
    
    if [ $? -ne 0 ]; then
        rm -f /tmp/attendance_status.tmp
        return
    fi
    
    status=$(cat /tmp/attendance_status.tmp)
    rm -f /tmp/attendance_status.tmp
    
    # Record attendance in CSV
    echo "$today,$emp_id,$status" >> "$ATTENDANCE_CSV"
    
    dialog --title "Success" --msgbox "Attendance marked successfully for $emp_id as $status!" 8 60
}

# Function to view attendance
view_attendance() {
    # Check if there are attendance records
    if [ $(wc -l < "$ATTENDANCE_CSV") -eq 1 ]; then
        dialog --title "Attendance Records" --msgbox "No attendance records found!" 8 40
        return
    fi
    
    # Create a formatted display of attendance
    tempfile=$(mktemp)
    
    echo "Attendance Records:" > "$tempfile"
    echo "---------------------------------" >> "$tempfile"
    echo "Date | Employee ID | Name | Status" >> "$tempfile"
    echo "---------------------------------" >> "$tempfile"
    
    # Join attendance and employee data to show names
    tail -n +2 "$ATTENDANCE_CSV" | sort -r | while IFS=, read -r date emp_id status; do
        emp_name=$(grep "^$emp_id," "$EMPLOYEES_CSV" | cut -d ',' -f 2)
        # Handle case where employee might be deleted but attendance record exists
        if [ -z "$emp_name" ]; then
            emp_name="[Deleted]"
        fi
        printf "%-10s | %-11s | %-15s | %s\n" "$date" "$emp_id" "$emp_name" "$status" >> "$tempfile"
    done
    
    dialog --title "Attendance Records" --textbox "$tempfile" 20 80
    
    rm -f "$tempfile"
}

# Function to update attendance
update_attendance() {
    # Check if there are attendance records
    if [ $(wc -l < "$ATTENDANCE_CSV") -eq 1 ]; then
        dialog --title "Error" --msgbox "No attendance records found!" 8 40
        return
    fi
    
    # Let user enter date
    dialog --title "Update Attendance" \
           --inputbox "Enter date (YYYY-MM-DD):" 8 40 "$(date +%Y-%m-%d)" \
           2> /tmp/date_selected.tmp
    
    if [ $? -ne 0 ]; then
        rm -f /tmp/date_selected.tmp
        return
    fi
    
    date_selected=$(cat /tmp/date_selected.tmp)
    rm -f /tmp/date_selected.tmp
    
    # Validate date format
    if ! validate_date "$date_selected"; then
        dialog --title "Error" --msgbox "Invalid date format. Please use YYYY-MM-DD." 8 50
        return
    fi
    
    # First, let the user select an employee ID
    select_employee_id
    
    # Check if employee was selected
    if [ ! -f "/tmp/employee_id_selected.tmp" ]; then
        return
    fi
    
    emp_id=$(cat /tmp/employee_id_selected.tmp)
    rm -f /tmp/employee_id_selected.tmp
    
    if [ -z "$emp_id" ]; then
        return
    fi
    
    # Check if attendance exists for this date and employee
    if ! grep -q "^$date_selected,$emp_id," "$ATTENDANCE_CSV"; then
        dialog --title "Error" --msgbox "No attendance record found for $emp_id on $date_selected!" 8 60
        return
    fi
    
    # Get current status
    current_status=$(grep "^$date_selected,$emp_id," "$ATTENDANCE_CSV" | cut -d ',' -f 3)
    
    # Ask for new attendance status
    dialog --title "Update Attendance" \
           --menu "Current status for $emp_id on $date_selected: $current_status\nSelect new status:" 15 60 2 \
           "Present" "Mark as Present" \
           "Absent" "Mark as Absent" \
           2> /tmp/attendance_status.tmp
    
    if [ $? -ne 0 ]; then
        rm -f /tmp/attendance_status.tmp
        return
    fi
    
    status=$(cat /tmp/attendance_status.tmp)
    rm -f /tmp/attendance_status.tmp
    
    # Update attendance in CSV
    sed -i "s|^$date_selected,$emp_id,.*$|$date_selected,$emp_id,$status|" "$ATTENDANCE_CSV"
    
    dialog --title "Success" --msgbox "Attendance updated successfully for $emp_id on $date_selected as $status!" 8 70
}

# Function to delete attendance
delete_attendance() {
    # Check if there are attendance records
    if [ $(wc -l < "$ATTENDANCE_CSV") -eq 1 ]; then
        dialog --title "Error" --msgbox "No attendance records found!" 8 40
        return
    fi
    
    # Let user enter date
    dialog --title "Delete Attendance" \
           --inputbox "Enter date (YYYY-MM-DD):" 8 40 "$(date +%Y-%m-%d)" \
           2> /tmp/date_selected.tmp
    
    if [ $? -ne 0 ]; then
        rm -f /tmp/date_selected.tmp
        return
    fi
    
    date_selected=$(cat /tmp/date_selected.tmp)
    rm -f /tmp/date_selected.tmp
    
    # Validate date format
    if ! validate_date "$date_selected"; then
        dialog --title "Error" --msgbox "Invalid date format. Please use YYYY-MM-DD." 8 50
        return
    fi
    
    # First, let the user select an employee ID
    select_employee_id
    
    # Check if employee was selected
    if [ ! -f "/tmp/employee_id_selected.tmp" ]; then
        return
    fi
    
    emp_id=$(cat /tmp/employee_id_selected.tmp)
    rm -f /tmp/employee_id_selected.tmp
    
    if [ -z "$emp_id" ]; then
        return
    fi
    
    # Check if attendance exists for this date and employee
    if ! grep -q "^$date_selected,$emp_id," "$ATTENDANCE_CSV"; then
        dialog --title "Error" --msgbox "No attendance record found for $emp_id on $date_selected!" 8 60
        return
    fi
    
    # Ask for confirmation
    dialog --title "Confirm Deletion" \
           --yesno "Are you sure you want to delete attendance record for $emp_id on $date_selected?" 8 75
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Delete attendance record from CSV
    sed -i "/^$date_selected,$emp_id,/d" "$ATTENDANCE_CSV"
    
    dialog --title "Success" --msgbox "Attendance record deleted successfully!" 8 50
}

# Function to view attendance summary
view_attendance_summary() {
    # Check if there are attendance records
    if [ $(wc -l < "$ATTENDANCE_CSV") -eq 1 ]; then
        dialog --title "Attendance Summary" --msgbox "No attendance records found!" 8 40
        return
    fi
    
    # Create a formatted summary of attendance
    tempfile=$(mktemp)
    
    echo "Attendance Summary:" > "$tempfile"
    echo "----------------------------------------" >> "$tempfile"
    echo "Employee ID | Name | Present | Absent | Total" >> "$tempfile"
    echo "----------------------------------------" >> "$tempfile"
    
    # Process employees one by one
    tail -n +2 "$EMPLOYEES_CSV" | while IFS=, read -r emp_id name department joining_date; do
        # Count present days
        present_count=$(grep "^[0-9-]*,$emp_id,Present" "$ATTENDANCE_CSV" | wc -l)
        
        # Count absent days
        absent_count=$(grep "^[0-9-]*,$emp_id,Absent" "$ATTENDANCE_CSV" | wc -l)
        
        # Calculate total
        total=$((present_count + absent_count))
        
        printf "%-12s | %-15s | %-7s | %-6s | %s\n" "$emp_id" "$name" "$present_count" "$absent_count" "$total" >> "$tempfile"
    done
    
    dialog --title "Attendance Summary" --textbox "$tempfile" 20 80
    
    rm -f "$tempfile"
}

# Function to view attendance on a specific date
attendance_on_date() {
    # Let user enter date
    dialog --title "Attendance by Date" \
           --inputbox "Enter date (YYYY-MM-DD):" 8 40 "$(date +%Y-%m-%d)" \
           2> /tmp/date_selected.tmp
    
    if [ $? -ne 0 ]; then
        rm -f /tmp/date_selected.tmp
        return
    fi
    
    date_selected=$(cat /tmp/date_selected.tmp)
    rm -f /tmp/date_selected.tmp
    
    # Validate date format
    if ! validate_date "$date_selected"; then
        dialog --title "Error" --msgbox "Invalid date format. Please use YYYY-MM-DD." 8 50
        return
    fi
    
    # Check if there are attendance records for this date
    if ! grep -q "^$date_selected," "$ATTENDANCE_CSV"; then
        dialog --title "Attendance Records" --msgbox "No attendance records found for $date_selected!" 8 55
        return
    fi
    
    # Create a formatted display of attendance for this date
    tempfile=$(mktemp)
    
    echo "Attendance for $date_selected:" > "$tempfile"
    echo "--------------------------------" >> "$tempfile"
    echo "Employee ID | Name | Status" >> "$tempfile"
    echo "--------------------------------" >> "$tempfile"
    
    # Join attendance and employee data to show names
    grep "^$date_selected," "$ATTENDANCE_CSV" | while IFS=, read -r date emp_id status; do
        emp_name=$(grep "^$emp_id," "$EMPLOYEES_CSV" | cut -d ',' -f 2)
        # Handle case where employee might be deleted but attendance record exists
        if [ -z "$emp_name" ]; then
            emp_name="[Deleted]"
        fi
        printf "%-12s | %-15s | %s\n" "$emp_id" "$emp_name" "$status" >> "$tempfile"
    done
    
    dialog --title "Attendance for $date_selected" --textbox "$tempfile" 20 70
    
    rm -f "$tempfile"
}

# Function to search for an employee
search_employee() {
    # Let user enter search term
    dialog --title "Search Employee" \
           --inputbox "Enter employee ID or name to search:" 8 50 \
           2> /tmp/search_term.tmp
    
    if [ $? -ne 0 ]; then
        rm -f /tmp/search_term.tmp
        return
    fi
    
    search_term=$(cat /tmp/search_term.tmp)
    rm -f /tmp/search_term.tmp
    
    if [ -z "$search_term" ]; then
        dialog --title "Error" --msgbox "Search term cannot be empty!" 8 40
        return
    fi
    
    # Search in employees.csv
    result=$(grep -i "$search_term" "$EMPLOYEES_CSV" | grep -v "^EmployeeID")
    
    if [ -z "$result" ]; then
        dialog --title "Search Results" --msgbox "No matching employees found!" 8 40
        return
    fi
    
    # Create a formatted display of search results
    tempfile=$(mktemp)
    
    echo "Search Results for '$search_term':" > "$tempfile"
    echo "----------------------------------" >> "$tempfile"
    echo "ID | Name | Department | Joining Date" >> "$tempfile"
    echo "----------------------------------" >> "$tempfile"
    
    echo "$result" | awk -F, '{printf "%-8s | %-15s | %-15s | %s\n", $1, $2, $3, $4}' >> "$tempfile"
    
    dialog --title "Search Results" --textbox "$tempfile" 20 80
    
    rm -f "$tempfile"
}

# Function to search attendance records
search_attendance() {
    # Let user enter search term
    dialog --title "Search Attendance" \
           --inputbox "Enter employee ID to search attendance:" 8 50 \
           2> /tmp/search_term.tmp
    
    if [ $? -ne 0 ]; then
        rm -f /tmp/search_term.tmp
        return
    fi
    
    search_term=$(cat /tmp/search_term.tmp)
    rm -f /tmp/search_term.tmp
    
    if [ -z "$search_term" ]; then
        dialog --title "Error" --msgbox "Search term cannot be empty!" 8 40
        return
    fi
    
    # Check if employee exists
    if ! employee_exists "$search_term"; then
        dialog --title "Error" --msgbox "Employee ID not found!" 8 40
        return
    fi
    
    # Search in attendance.csv
    result=$(grep ",$search_term," "$ATTENDANCE_CSV")
    
    if [ -z "$result" ]; then
        dialog --title "Search Results" --msgbox "No attendance records found for this employee!" 8 60
        return
    fi
    
    # Get employee name
    emp_name=$(grep "^$search_term," "$EMPLOYEES_CSV" | cut -d ',' -f 2)
    
    # Create a formatted display of search results
    tempfile=$(mktemp)
    
    echo "Attendance Records for $search_term ($emp_name):" > "$tempfile"
    echo "----------------------------" >> "$tempfile"
    echo "Date | Status" >> "$tempfile"
    echo "----------------------------" >> "$tempfile"
    
    echo "$result" | sort -r | awk -F, '{printf "%-10s | %s\n", $1, $3}' >> "$tempfile"
    
    dialog --title "Attendance Search Results" --textbox "$tempfile" 20 70
    
    rm -f "$tempfile"
}

# Main function - display menu and handle user choices
main() {
    while true; do
        choice=$(dialog --clear --title "Employee Attendance Tracker" \
                        --menu "Select an option:" 20 60 13 \
                        "1" "Add Employee" \
                        "2" "Update Employee Details" \
                        "3" "Delete Employee" \
                        "4" "View Employee List" \
                        "5" "Mark Attendance" \
                        "6" "View Attendance" \
                        "7" "Update Attendance" \
                        "8" "Delete Attendance" \
                        "9" "View Attendance Summary" \
                        "10" "Attendance on Specific Date" \
                        "11" "Search Employee" \
                        "12" "Search Attendance" \
                        "13" "Exit" \
                        3>&1 1>&2 2>&3)
        
        # Exit if Cancel is pressed
        if [ $? -ne 0 ]; then
            clear
            echo "Goodbye!"
            exit 0
        fi
        
        case $choice in
            1) add_employee ;;
            2) update_employee ;;
            3) delete_employee ;;
            4) view_employee_list ;;
            5) mark_attendance ;;
            6) view_attendance ;;
            7) update_attendance ;;
            8) delete_attendance ;;
            9) view_attendance_summary ;;
            10) attendance_on_date ;;
            11) search_employee ;;
            12) search_attendance ;;
            13) clear
                echo "Thank you for using Employee Attendance Tracker!"
                exit 0
                ;;
        esac
    done
}

# Start the program
main

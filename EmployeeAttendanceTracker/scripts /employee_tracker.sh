You said:
#!/bin/bash

# Employee Attendance Tracker
# A dialog-based shell script for tracking employee attendance

# Define paths for CSV files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$BASE_DIR/data"
EMPLOYEES_CSV="$DATA_DIR/employees.csv"
ATTENDANCE_CSV="$DATA_DIR/attendance.csv"

# Create directories if they don't exist
mkdir -p "$DATA_DIR"

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "dialog package is not installed. Please install it first."
    echo "For Debian/Ubuntu: sudo apt-get install dialog"
    echo "For Red Hat/CentOS: sudo yum install dialog"
    exit 1
fi

# Initialize CSV files if they don't exist
initialize_files() {
    # Create employees.csv if it doesn't exist
    if [ ! -f "$EMPLOYEES_CSV" ]; then
        echo "Employee_ID,Name,Department,Joining_Date" > "$EMPLOYEES_CSV"
        chmod 644 "$EMPLOYEES_CSV"
    fi

    # Create attendance.csv if it doesn't exist
    if [ ! -f "$ATTENDANCE_CSV" ]; then
        echo "Date,Employee_ID,Status" > "$ATTENDANCE_CSV"
        chmod 644 "$ATTENDANCE_CSV"
    fi
}

# Function to show error message
show_error() {
    dialog --title "Error" --msgbox "$1" 8 40
}

# Function to show success message
show_success() {
    dialog --title "Success" --msgbox "$1" 8 40
}

# Function to validate date format (YYYY-MM-DD)
validate_date() {
    if [[ ! "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 1
    fi
    
    # Further validation can be added here if needed
    return 0
}

# Function to validate employee ID (numeric)
validate_employee_id() {
    if [[ ! "$1" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# Function to check if employee ID exists
check_employee_exists() {
    local id=$1
    grep -q "^$id," "$EMPLOYEES_CSV"
    return $?
}

# Function to add a new employee
add_employee() {
    # Get employee details using dialog
    employee_id=$(dialog --title "Add Employee" --inputbox "Enter Employee ID (numeric):" 8 40 2>&1 >/dev/tty)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Validate Employee ID
    if ! validate_employee_id "$employee_id"; then
        show_error "Invalid Employee ID. Please enter a numeric value."
        return
    fi
    
    # Check if employee ID already exists
    if grep -q "^$employee_id," "$EMPLOYEES_CSV"; then
        show_error "Employee ID $employee_id already exists."
        return
    fi
    
    name=$(dialog --title "Add Employee" --inputbox "Enter Employee Name:" 8 40 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    department=$(dialog --title "Add Employee" --inputbox "Enter Department:" 8 40 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    joining_date=$(dialog --title "Add Employee" --inputbox "Enter Joining Date (YYYY-MM-DD):" 8 40 "$(date +%Y-%m-%d)" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Validate date format
    if ! validate_date "$joining_date"; then
        show_error "Invalid date format. Please use YYYY-MM-DD."
        return
    fi
    
    # Add employee to CSV
    echo "$employee_id,$name,$department,$joining_date" >> "$EMPLOYEES_CSV"
    
    show_success "Employee added successfully."
}

# Function to update an employee
update_employee() {
    # First, let the user select an employee ID
    if [ ! -s "$EMPLOYEES_CSV" ] || [ $(wc -l < "$EMPLOYEES_CSV") -le 1 ]; then
        show_error "No employees found."
        return
    fi
    
    # Create a temporary file for the employee list
    temp_file=$(mktemp)
    tail -n +2 "$EMPLOYEES_CSV" | awk -F, '{print $1 " - " $2 " (" $3 ")"}' > "$temp_file"
    
    # Ask user to select an employee
    employee_selection=$(dialog --title "Update Employee" --menu "Select an employee to update:" 15 60 8 --file "$temp_file" 2>&1 >/dev/tty)
    rm "$temp_file"
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Extract employee ID from selection
    employee_id=$(echo "$employee_selection" | cut -d' ' -f1)
    
    # Get current employee data
    employee_data=$(grep "^$employee_id," "$EMPLOYEES_CSV")
    current_name=$(echo "$employee_data" | awk -F, '{print $2}')
    current_department=$(echo "$employee_data" | awk -F, '{print $3}')
    current_joining_date=$(echo "$employee_data" | awk -F, '{print $4}')
    
    # Get updated details
    name=$(dialog --title "Update Employee" --inputbox "Enter New Name:" 8 40 "$current_name" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    department=$(dialog --title "Update Employee" --inputbox "Enter New Department:" 8 40 "$current_department" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    joining_date=$(dialog --title "Update Employee" --inputbox "Enter New Joining Date (YYYY-MM-DD):" 8 40 "$current_joining_date" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Validate date format
    if ! validate_date "$joining_date"; then
        show_error "Invalid date format. Please use YYYY-MM-DD."
        return
    fi
    
    # Update employee in CSV
    sed -i "s|^$employee_id,.*|$employee_id,$name,$department,$joining_date|" "$EMPLOYEES_CSV"
    
    show_success "Employee updated successfully."
}

# Function to delete an employee
delete_employee() {
    # First, let the user select an employee ID
    if [ ! -s "$EMPLOYEES_CSV" ] || [ $(wc -l < "$EMPLOYEES_CSV") -le 1 ]; then
        show_error "No employees found."
        return
    fi
    
    # Create a temporary file for the employee list
    temp_file=$(mktemp)
    tail -n +2 "$EMPLOYEES_CSV" | awk -F, '{print $1 " - " $2 " (" $3 ")"}' > "$temp_file"
    
    # Ask user to select an employee
    employee_selection=$(dialog --title "Delete Employee" --menu "Select an employee to delete:" 15 60 8 --file "$temp_file" 2>&1 >/dev/tty)
    rm "$temp_file"
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Extract employee ID from selection
    employee_id=$(echo "$employee_selection" | cut -d' ' -f1)
    
    # Confirm deletion
    dialog --title "Confirm" --yesno "Are you sure you want to delete this employee? This will also delete all attendance records for this employee." 8 60
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Delete employee from CSV
    sed -i "/^$employee_id,/d" "$EMPLOYEES_CSV"
    
    # Also delete all attendance records for this employee
    sed -i "/^[^,]*,$employee_id,/d" "$ATTENDANCE_CSV"
    
    show_success "Employee and associated attendance records deleted successfully."
}

# Function to view employee list
view_employee_list() {
    if [ ! -s "$EMPLOYEES_CSV" ] || [ $(wc -l < "$EMPLOYEES_CSV") -le 1 ]; then
        show_error "No employees found."
        return
    fi
    
    # Create a temporary file for the employee list
    temp_file=$(mktemp)
    echo -e "ID\tName\tDepartment\tJoining Date" > "$temp_file"
    echo -e "------------------------------------------------------------" >> "$temp_file"
    tail -n +2 "$EMPLOYEES_CSV" | awk -F, '{print $1 "\t" $2 "\t" $3 "\t" $4}' >> "$temp_file"
    
    # Show the employee list
    dialog --title "Employee List" --textbox "$temp_file" 20 80
    
    # Clean up
    rm "$temp_file"
}

# Function to mark attendance
mark_attendance() {
    # Get today's date
    today=$(date +%Y-%m-%d)
    
    # Ask for a different date if needed
    attendance_date=$(dialog --title "Mark Attendance" --inputbox "Enter Date (YYYY-MM-DD):" 8 40 "$today" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Validate date format
    if ! validate_date "$attendance_date"; then
        show_error "Invalid date format. Please use YYYY-MM-DD."
        return
    fi
    
    # Check if there are any employees
    if [ ! -s "$EMPLOYEES_CSV" ] || [ $(wc -l < "$EMPLOYEES_CSV") -le 1 ]; then
        show_error "No employees found. Please add employees first."
        return
    fi
    
    # Create a temporary file for the dialog checklist
    temp_file=$(mktemp)
    
    # Create checklist items with all employees (default: present)
    while IFS=, read -r id name department joining_date; do
        # Skip header line
        if [ "$id" = "Employee_ID" ]; then
            continue
        fi
        
        # Check if attendance is already marked for this employee on this date
        current_status=""
        if grep -q "^$attendance_date,$id," "$ATTENDANCE_CSV"; then
            current_status=$(grep "^$attendance_date,$id," "$ATTENDANCE_CSV" | cut -d, -f3)
        fi
        
        # Set default status based on current status or default to Present
        status_flag="on"
        if [ "$current_status" = "Absent" ]; then
            status_flag="off"
        fi
        
        echo "$id \"$name\" $status_flag" >> "$temp_file"
    done < "$EMPLOYEES_CSV"
    
    # Use dialog to mark attendance with a checklist
    present_ids=$(dialog --title "Mark Attendance for $attendance_date" --checklist "Select present employees:" 15 60 8 --file "$temp_file" 2>&1 >/dev/tty)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        rm "$temp_file"
        return
    fi
    
    # Process the attendance
    while IFS=, read -r id name department joining_date; do
        # Skip header line
        if [ "$id" = "Employee_ID" ]; then
            continue
        fi
        
        # Determine status
        status="Absent"
        for present_id in $present_ids; do
            present_id=$(echo "$present_id" | tr -d '"')
            if [ "$id" = "$present_id" ]; then
                status="Present"
                break
            fi
        done
        
        # Remove existing record for this employee on this date if it exists
        sed -i "/^$attendance_date,$id,/d" "$ATTENDANCE_CSV"
        
        # Add the new attendance record
        echo "$attendance_date,$id,$status" >> "$ATTENDANCE_CSV"
    done < "$EMPLOYEES_CSV"
    
    # Clean up
    rm "$temp_file"
    
    show_success "Attendance marked successfully for $attendance_date."
}

# Function to view attendance for a specific date
view_date_attendance() {
    # Get today's date
    today=$(date +%Y-%m-%d)
    
    # Ask for a specific date
    attendance_date=$(dialog --title "View Attendance" --inputbox "Enter Date (YYYY-MM-DD):" 8 40 "$today" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Validate date format
    if ! validate_date "$attendance_date"; then
        show_error "Invalid date format. Please use YYYY-MM-DD."
        return
    fi
    
    # Check if attendance records exist for this date
    if ! grep -q "^$attendance_date," "$ATTENDANCE_CSV"; then
        show_error "No attendance records found for $attendance_date."
        return
    fi
    
    # Create a temporary file for the attendance list
    temp_file=$(mktemp)
    echo -e "Date: $attendance_date\n" > "$temp_file"
    echo -e "ID\tName\tDepartment\tStatus" >> "$temp_file"
    echo -e "------------------------------------------------------------" >> "$temp_file"
    
    # Process each attendance record for the date
    grep "^$attendance_date," "$ATTENDANCE_CSV" | while IFS=, read -r date id status; do
        # Get employee details
        employee_data=$(grep "^$id," "$EMPLOYEES_CSV")
        
        if [ -n "$employee_data" ]; then
            name=$(echo "$employee_data" | awk -F, '{print $2}')
            department=$(echo "$employee_data" | awk -F, '{print $3}')
            echo -e "$id\t$name\t$department\t$status" >> "$temp_file"
        else
            echo -e "$id\tUnknown\tUnknown\t$status" >> "$temp_file"
        fi
    done
    
    # Count present and absent
    present_count=$(grep "^$attendance_date," "$ATTENDANCE_CSV" | grep -c ",Present$")
    absent_count=$(grep "^$attendance_date," "$ATTENDANCE_CSV" | grep -c ",Absent$")
    total_count=$((present_count + absent_count))
    
    echo -e "\n------------------------------------------------------------" >> "$temp_file"
    echo -e "Summary: Total: $total_count, Present: $present_count, Absent: $absent_count" >> "$temp_file"
    
    # Show the attendance list
    dialog --title "Attendance for $attendance_date" --textbox "$temp_file" 20 80
    
    # Clean up
    rm "$temp_file"
}

# Function to update attendance
update_attendance() {
    # Ask for a specific date
    today=$(date +%Y-%m-%d)
    attendance_date=$(dialog --title "Update Attendance" --inputbox "Enter Date (YYYY-MM-DD):" 8 40 "$today" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Validate date format
    if ! validate_date "$attendance_date"; then
        show_error "Invalid date format. Please use YYYY-MM-DD."
        return
    fi
    
    # Check if attendance records exist for this date
    if ! grep -q "^$attendance_date," "$ATTENDANCE_CSV"; then
        show_error "No attendance records found for $attendance_date."
        return
    fi
    
    # Create a temporary file for the employee list
    temp_file=$(mktemp)
    
    # Loop through all attendance records for this date
    grep "^$attendance_date," "$ATTENDANCE_CSV" | while IFS=, read -r date id status; do
        # Get employee name
        name=$(grep "^$id," "$EMPLOYEES_CSV" | awk -F, '{print $2}')
        if [ -z "$name" ]; then
            name="Unknown"
        fi
        
        # Add to the list
        echo "$id \"$name - Currently $status\" $status" >> "$temp_file"
    done
    
    # Use dialog to update attendance with a checklist
    present_ids=$(dialog --title "Update Attendance for $attendance_date" --checklist "Select present employees:" 15 70 8 --file "$temp_file" 2>&1 >/dev/tty)
    
    # Check if canceled
    if [ $? -ne 0 ]; then
        rm "$temp_file"
        return
    fi
    
    # Get all employee IDs with attendance for this date
    employee_ids=$(grep "^$attendance_date," "$ATTENDANCE_CSV" | cut -d, -f2)
    
    # Process the attendance updates
    for id in $employee_ids; do
        # Determine status
        status="Absent"
        for present_id in $present_ids; do
            present_id=$(echo "$present_id" | tr -d '"')
            if [ "$id" = "$present_id" ]; then
                status="Present"
                break
            fi
        done
        
        # Update the attendance record
        sed -i "s|^$attendance_date,$id,.*|$attendance_date,$id,$status|" "$ATTENDANCE_CSV"
    done
    
    # Clean up
    rm "$temp_file"
    
    show_success "Attendance updated successfully for $attendance_date."
}

# Function to delete attendance
delete_attendance() {
    # Ask for a specific date
    today=$(date +%Y-%m-%d)
    attendance_date=$(dialog --title "Delete Attendance" --inputbox "Enter Date (YYYY-MM-DD):" 8 40 "$today" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Validate date format
    if ! validate_date "$attendance_date"; then
        show_error "Invalid date format. Please use YYYY-MM-DD."
        return
    fi
    
    # Check if attendance records exist for this date
    if ! grep -q "^$attendance_date," "$ATTENDANCE_CSV"; then
        show_error "No attendance records found for $attendance_date."
        return
    fi
    
    # Confirm deletion
    dialog --title "Confirm" --yesno "Are you sure you want to delete all attendance records for $attendance_date?" 8 60
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Delete all attendance records for this date
    sed -i "/^$attendance_date,/d" "$ATTENDANCE_CSV"
    
    show_success "Attendance records deleted successfully for $attendance_date."
}

# Function to view attendance summary
view_attendance_summary() {
    # Check if there are any attendance records
    if [ ! -s "$ATTENDANCE_CSV" ] || [ $(wc -l < "$ATTENDANCE_CSV") -le 1 ]; then
        show_error "No attendance records found."
        return
    fi
    
    # Create a temporary file for the summary
    temp_file=$(mktemp)
    echo -e "Attendance Summary\n" > "$temp_file"
    echo -e "ID\tName\tDepartment\tPresent\tAbsent\tTotal\tPercentage" >> "$temp_file"
    echo -e "------------------------------------------------------------" >> "$temp_file"
    
    # Get unique employee IDs from attendance records
    employee_ids=$(tail -n +2 "$ATTENDANCE_CSV" | cut -d, -f2 | sort -u)
    
    # Process each employee
    for id in $employee_ids; do
        # Get employee details
        employee_data=$(grep "^$id," "$EMPLOYEES_CSV")
        
        if [ -n "$employee_data" ]; then
            name=$(echo "$employee_data" | awk -F, '{print $2}')
            department=$(echo "$employee_data" | awk -F, '{print $3}')
        else
            name="Unknown"
            department="Unknown"
        fi
        
        # Count present and absent
        present_count=$(grep -c "^[^,]*,$id,Present$" "$ATTENDANCE_CSV")
        absent_count=$(grep -c "^[^,]*,$id,Absent$" "$ATTENDANCE_CSV")
        total_count=$((present_count + absent_count))
        
        # Calculate percentage
        if [ $total_count -gt 0 ]; then
            percentage=$((present_count * 100 / total_count))
        else
            percentage=0
        fi
        
        echo -e "$id\t$name\t$department\t$present_count\t$absent_count\t$total_count\t$percentage%" >> "$temp_file"
    done
    
    # Show the summary
    dialog --title "Attendance Summary" --textbox "$temp_file" 20 80
    
    # Clean up
    rm "$temp_file"
}

# Function to search employee
search_employee() {
    # Get search term
    search_term=$(dialog --title "Search Employee" --inputbox "Enter search term (ID, Name, or Department):" 8 40 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Check if employees.csv exists and has data
    if [ ! -s "$EMPLOYEES_CSV" ] || [ $(wc -l < "$EMPLOYEES_CSV") -le 1 ]; then
        show_error "No employees found."
        return
    fi
    
    # Create a temporary file for search results
    temp_file=$(mktemp)
    echo -e "Search Results for: \"$search_term\"\n" > "$temp_file"
    echo -e "ID\tName\tDepartment\tJoining Date" >> "$temp_file"
    echo -e "------------------------------------------------------------" >> "$temp_file"
    
    # Search for matches in employees.csv (case-insensitive)
    grep -i "$search_term" "$EMPLOYEES_CSV" | while IFS=, read -r id name department joining_date; do
        # Skip header line
        if [ "$id" = "Employee_ID" ]; then
            continue
        fi
        
        echo -e "$id\t$name\t$department\t$joining_date" >> "$temp_file"
    done
    
    # Count results
    result_count=$(grep -c -v "^Search\|^ID\|^------" "$temp_file")
    
    if [ $result_count -eq 0 ]; then
        show_error "No matching employees found."
        rm "$temp_file"
        return
    fi
    
    # Add result count to the output
    echo -e "\nTotal Results: $result_count" >> "$temp_file"
    
    # Show search results
    dialog --title "Employee Search Results" --textbox "$temp_file" 20 80
    
    # Clean up
    rm "$temp_file"
}

# Function to search attendance
search_attendance() {
    # Get search date range
    start_date=$(dialog --title "Search Attendance" --inputbox "Enter Start Date (YYYY-MM-DD):" 8 40 "$(date -d '30 days ago' +%Y-%m-%d)" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Validate date format
    if ! validate_date "$start_date"; then
        show_error "Invalid date format. Please use YYYY-MM-DD."
        return
    fi
    
    end_date=$(dialog --title "Search Attendance" --inputbox "Enter End Date (YYYY-MM-DD):" 8 40 "$(date +%Y-%m-%d)" 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Validate date format
    if ! validate_date "$end_date"; then
        show_error "Invalid date format. Please use YYYY-MM-DD."
        return
    fi
    
    # Get employee ID (optional)
    employee_id=$(dialog --title "Search Attendance" --inputbox "Enter Employee ID (leave blank for all employees):" 8 40 2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then return; fi
    
    # Create a temporary file for search results
    temp_file=$(mktemp)
    echo -e "Attendance Search Results\n" > "$temp_file"
    echo -e "Date Range: $start_date to $end_date" >> "$temp_file"
    if [ -n "$employee_id" ]; then
        # Validate employee ID if provided
        if ! validate_employee_id "$employee_id"; then
            show_error "Invalid Employee ID. Please enter a numeric value."
            rm "$temp_file"
            return
        fi
        
        # Get employee name
        employee_name=$(grep "^$employee_id," "$EMPLOYEES_CSV" | awk -F, '{print $2}')
        if [ -z "$employee_name" ]; then
            employee_name="Unknown"
        fi
        echo -e "Employee: $employee_id - $employee_name\n" >> "$temp_file"
    else
        echo -e "Employee: All\n" >> "$temp_file"
    fi
    
    echo -e "Date\tID\tName\tDepartment\tStatus" >> "$temp_file"
    echo -e "------------------------------------------------------------" >> "$temp_file"
    
    # Process each line in attendance.csv
    while IFS=, read -r date id status; do
        # Skip header line
        if [ "$date" = "Date" ]; then
            continue
        fi
        
        # Check if date is within range
        if [[ "$date" < "$start_date" || "$date" > "$end_date" ]]; then
            continue
        fi
        
        # Check employee ID if specified
        if [ -n "$employee_id" ] && [ "$id" != "$employee_id" ]; then
            continue
        fi
        
        # Get employee details
        employee_data=$(grep "^$id," "$EMPLOYEES_CSV")
        
        if [ -n "$employee_data" ]; then
            name=$(echo "$employee_data" | awk -F, '{print $2}')
            department=$(echo "$employee_data" | awk -F, '{print $3}')
        else
            name="Unknown"
            department="Unknown"
        fi
        
        echo -e "$date\t$id\t$name\t$department\t$status" >> "$temp_file"
    done < "$ATTENDANCE_CSV"
    
    # Count results
    result_count=$(grep -c -v "^Attendance\|^Date Range\|^Employee:\|^Date\t\|^------" "$temp_file")
    
    if [ $result_count -eq 0 ]; then
        show_error "No matching attendance records found."
        rm "$temp_file"
        return
    fi
    
    # Count present and absent
    present_count=$(grep -c "Present$" "$temp_file")
    absent_count=$(grep -c "Absent$" "$temp_file")
    
    # Add summary to the output
    echo -e "\n------------------------------------------------------------" >> "$temp_file"
    echo -e "Summary: Total Records: $result_count, Present: $present_count, Absent: $absent_count" >> "$temp_file"
    
    # Show search results
    dialog --title "Attendance Search Results" --textbox "$temp_file" 20 80
    
    # Clean up
    rm "$temp_file"
}

# Main function - display the main menu
main_menu() {
    while true; do
        # Display the main menu
        choice=$(dialog --title "Employee Attendance Tracker" --menu "Select an option:" 18 60 10 \
            1 "Add Employee" \
            2 "Update Employee" \
            3 "Delete Employee" \
            4 "View Employee List" \
            5 "Mark Attendance" \
            6 "View Attendance for Date" \
            7 "Update Attendance" \
            8 "Delete Attendance" \
            9 "View Attendance Summary" \
            10 "Search Employee" \
            11 "Search Attendance" \
            12 "Exit" 2>&1 >/dev/tty)
        
        # Check if user pressed Cancel or ESC
        if [ $? -ne 0 ]; then
            exit 0
        fi
        
        # Process the user's choice
        case $choice in
            1) add_employee ;;
            2) update_employee ;;
            3) delete_employee ;;
            4) view_employee_list ;;
            5) mark_attendance ;;
            6) view_date_attendance ;;
            7) update_attendance ;;
            8) delete_attendance ;;
            9) view_attendance_summary ;;
            10) search_employee ;;
            11) search_attendance ;;
            12) 
                clear
                echo "Thank you for using Employee Attendance Tracker!"
                exit 0
                ;;
        esac
    done
}

# Initialize CSV files
initialize_files

# Start the application
main_menu

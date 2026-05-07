package main

import "fmt"

func main() {
	query := "select * from users"
	result := runQuery(query)
	fmt.Println(result)
}

func runQuery(query string) string {
	if cached := lookupCache(query); cached != "" {
		return cached
	}
	rows := executeSQL(query)
	return formatRows(rows)
}

func lookupCache(query string) string {
	return ""
}

func executeSQL(query string) []string {
	return []string{"alice", "bob"}
}

func formatRows(rows []string) string {
	return fmt.Sprintf("%v", rows)
}

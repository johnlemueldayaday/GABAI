from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn


OUT = r"C:\APP\Grocery-Wallet\output\docs\GABAY_Finalized_Chapters_1_and_2.docx"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def set_cell_margins(cell, top=80, start=120, bottom=80, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, v in {"top": top, "start": start, "bottom": bottom, "end": end}.items():
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")


def set_table_width(table, widths):
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for row in table.rows:
        for idx, width in enumerate(widths):
            row.cells[idx].width = Inches(width)
            set_cell_margins(row.cells[idx])
            row.cells[idx].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def mark_header_row(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def add_page_number(section):
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run()
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = "PAGE"
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.append(fld_char1)
    run._r.append(instr_text)
    run._r.append(fld_char2)


def style_document(doc):
    section = doc.sections[0]
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)
    section.header_distance = Inches(0.492)
    section.footer_distance = Inches(0.492)
    add_page_number(section)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Calibri"
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Calibri")
    normal.font.size = Pt(11)
    normal.paragraph_format.line_spacing = 1.25
    normal.paragraph_format.space_after = Pt(6)

    for style_name, size, color, before, after in [
        ("Heading 1", 16, RGBColor(46, 116, 181), 18, 10),
        ("Heading 2", 13, RGBColor(46, 116, 181), 12, 6),
        ("Heading 3", 12, RGBColor(31, 77, 120), 8, 4),
    ]:
        style = styles[style_name]
        style.font.name = "Calibri"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Calibri")
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = color
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)


def para(doc, text="", style=None, bold_label=None):
    p = doc.add_paragraph(style=style)
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    if bold_label:
        r = p.add_run(bold_label)
        r.bold = True
        p.add_run(text)
    else:
        p.add_run(text)
    return p


def centered(doc, text, size=12, bold=False):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(text)
    r.font.size = Pt(size)
    r.bold = bold
    return p


def bullet(doc, text):
    p = doc.add_paragraph(style="List Bullet")
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.add_run(text)
    return p


def number(doc, text):
    p = doc.add_paragraph(style="List Number")
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.add_run(text)
    return p


def add_matrix(doc, headers, rows, widths):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    hdr = table.rows[0].cells
    mark_header_row(table.rows[0])
    for i, header in enumerate(headers):
        hdr[i].text = header
        for run in hdr[i].paragraphs[0].runs:
            run.bold = True
        set_cell_shading(hdr[i], "F2F4F7")
    for row in rows:
        cells = table.add_row().cells
        for i, value in enumerate(row):
            cells[i].text = value
    set_table_width(table, widths)
    doc.add_paragraph()
    return table


def build():
    doc = Document()
    style_document(doc)

    centered(doc, "GABAY APP: GUIDED ASSET BUDGETING AI FOR YOU", 14, True)
    centered(doc, "A Thesis Presented to", 12)
    centered(doc, "The Faculty of the Bachelor of Science in Information Technology", 12)
    centered(doc, "Father Saturnino Urios University", 12)
    centered(doc, "Butuan City", 12)
    doc.add_paragraph()
    centered(doc, "In Partial Fulfillment of the Requirements for the Degree of", 12)
    centered(doc, "Bachelor of Science in Information Technology", 12)
    doc.add_paragraph()
    centered(doc, "by", 12)
    for name in [
        "John Lemuel H. Dayaday",
        "Jeric O. Blanco",
        "Abby Angelo B. Auxtero",
        "Mil Kieven Bugasia",
    ]:
        centered(doc, name, 12)
    doc.add_paragraph()
    centered(doc, "June 2026", 12)

    doc.add_page_break()
    doc.add_heading("Chapter 1", level=1)
    centered(doc, "THE PROBLEM AND REVIEW OF RELATED LITERATURE", 12, True)

    doc.add_heading("Background of the Study", level=2)
    para(doc, "Financial management is an everyday concern for Filipino individuals and households. Daily expenses such as food, transportation, utilities, school needs, online purchases, and emergency costs require users to monitor how much money comes in, how much is spent, and how much remains for future obligations. However, many people still rely on memory, handwritten notes, screenshots, or scattered records when tracking their expenses. These practices may be familiar and convenient at first, but they are also vulnerable to forgotten transactions, inaccurate totals, lost records, and weak follow-through.")
    para(doc, "The need for practical budgeting support is strengthened by the economic reality of household spending in the Philippines. The Philippine Statistics Authority identifies the Family Income and Expenditure Survey as the national source of data for family income and expenditure patterns, including spending behavior and household living conditions (Philippine Statistics Authority, 2022). For many households, food, bills, and routine purchases take a significant portion of available income. When users do not clearly see their spending patterns, they may overspend on non-priority items, forget upcoming bills, or fail to adjust their budget before their funds run low.")
    para(doc, "Mobile applications can help address this problem because smartphones are already part of daily life. A mobile budgeting tool can make transaction recording faster, provide automatic computation, and show summaries that are difficult to maintain manually. However, many financial management applications are generic, internet-dependent, or focused only on one function such as expense tracking. Some users also become discouraged when an app feels complicated, requires too much setup, or does not match local budgeting habits such as grocery planning, bill reminders, and irregular spending.")
    para(doc, "GABAY APP: Guided Asset Budgeting AI for You was developed as an offline-first mobile financial management application for Filipino users. The system combines expense tracking, budget monitoring, grocery list management, bill tracking, price history, analytics, and a rule-based AI assistant named BAI or Brother AI. Instead of connecting to banks or e-wallets, users manually input transactions and financial records. This keeps the system simple, avoids handling real money, and supports users who want to track personal or household finances without requiring continuous internet connection.")
    para(doc, "The role of BAI in the system is to make financial tracking more engaging and useful. BAI analyzes user-inputted records through predefined rules and local app data. It can help users check budgets, identify overspending, summarize upcoming bills, assist with grocery-related decisions, and respond to simple finance-related queries. The system does not provide professional investment, legal, or loan advice. Its function is limited to budgeting support, reminders, summaries, and awareness-building based on the user's own records.")
    para(doc, "This study focuses on the design and development of GABAY APP as a practical mobile tool for Filipino users in Butuan City. By providing an offline-first and user-friendly system, the study aims to support better awareness of spending behavior and reduce the difficulty of manual expense tracking.")

    doc.add_heading("Review of Related Literature", level=2)
    doc.add_heading("Mobile Personal Finance and Budget Tracking", level=3)
    para(doc, "Budget tracking is connected to financial awareness because users are more likely to make informed decisions when they can see their income, expenses, and remaining funds. Hilgert, Hogarth, and Beverly (2003) discussed the relationship between financial knowledge and financial management behavior, emphasizing that money management practices are associated with better financial outcomes. In mobile systems, this principle is applied through transaction logs, budget limits, and summaries that give users immediate feedback.")
    para(doc, "Technology acceptance is also relevant to budgeting applications. Davis (1989) explained that perceived usefulness and perceived ease of use influence whether users accept information systems. For GABAY, this means the application must not only provide correct computations but also remain simple enough for ordinary users. If the app is confusing, users may return to manual notes or stop tracking expenses altogether.")

    doc.add_heading("Grocery and Household Expense Management", level=3)
    para(doc, "Grocery spending is one of the most frequent forms of household expenditure. Digital grocery lists may support planning by allowing users to prepare items, estimate costs, and avoid unnecessary purchases. Huang and Yang (2019) examined shopping list behavior and showed that list-making can influence how consumers plan and shop. This supports the inclusion of grocery list management in GABAY because grocery decisions often affect whether users stay within budget.")
    para(doc, "For Filipino users, grocery management is not only a list-making activity but also a budgeting activity. Prices can vary by store, market, and purchase timing. GABAY responds to this by allowing users to manage grocery lists, record item prices, and review spending from previous shopping activities. This supports price awareness and reduces dependence on memory.")

    doc.add_heading("AI-Assisted and Rule-Based Financial Support", level=3)
    para(doc, "Artificial intelligence in consumer applications can help users interpret data, but AI must be implemented responsibly. Shneiderman (2020) emphasized human-centered AI that remains reliable, safe, and trustworthy. In the context of GABAY, this means the assistant should not pretend to be a professional financial adviser. Instead, BAI gives rule-based budgeting support using the information already stored in the app.")
    para(doc, "A rule-based assistant is appropriate for the present study because it can operate offline, produce predictable responses, and avoid the cost and privacy risks of transmitting financial records to a cloud chatbot. BAI uses predefined conditions such as remaining budget, recorded expenses, upcoming bills, and grocery totals to generate reminders and suggestions. This design supports transparency because the system's recommendations are based on visible user data rather than hidden external processing.")

    doc.add_heading("Offline-First Mobile Application Design", level=3)
    para(doc, "Offline-first design is important when applications must remain useful even without stable internet access. Kleppmann, Wiggins, van Hardenberg, and McGranaghan (2019) explained local-first software as a design direction that prioritizes user ownership of data and the ability to work without depending entirely on the cloud. GABAY applies this principle by storing user records locally through SharedPreferences and by allowing the core features to function without bank, e-wallet, or remote server integration.")
    para(doc, "This approach is suitable for a budgeting app because financial tracking should still be available when users are in stores, commuting, or working in areas with weak connectivity. Offline-first storage also supports privacy because financial records remain on the user's device unless future versions add optional cloud features with consent.")

    doc.add_heading("Software Quality and User Evaluation", level=3)
    para(doc, "Since GABAY is a system-based capstone, evaluating the quality of the developed application is necessary. ISO/IEC 25010 provides a model for software quality evaluation, including functional suitability, usability, reliability, performance efficiency, compatibility, security, maintainability, and portability (International Organization for Standardization, 2011). This study uses selected ISO/IEC 25010 criteria that are relevant to the developed mobile application.")

    doc.add_heading("Related Applications", level=2)
    add_matrix(
        doc,
        ["Application", "Common Features", "Gap Addressed by GABAY"],
        [
            ["Generic expense tracker apps", "Manual expense entry, categories, reports", "GABAY combines expense tracking with grocery budgeting, bill monitoring, offline use, and BAI support."],
            ["E-wallet applications", "Payments, wallet balance, transaction history", "GABAY does not process real money and focuses on budgeting awareness across cash and manual records."],
            ["Spreadsheet or notebook tracking", "Flexible but manual recording", "GABAY automates totals, reminders, analytics, and budget status visualization."],
            ["Shopping list applications", "Item lists and purchase planning", "GABAY connects grocery lists with budget limits, price history, and spending analytics."],
        ],
        [1.7, 2.2, 2.6],
    )

    doc.add_heading("Theoretical Framework", level=2)
    para(doc, "This study is anchored on the Technology Acceptance Model and the Theory of Planned Behavior. The Technology Acceptance Model explains that users are more likely to accept a system when they perceive it as useful and easy to use (Davis, 1989). GABAY applies this by providing simple screens for recording expenses, budgets, bills, and grocery items, while BAI helps users understand their records through conversational support.")
    para(doc, "The Theory of Planned Behavior explains that behavior is influenced by attitude, subjective norms, and perceived behavioral control (Ajzen, 1991). In budgeting, users may intend to manage money better but fail when they lack tools, reminders, or clear feedback. GABAY increases perceived control by showing budget status, upcoming obligations, and spending summaries.")

    doc.add_heading("Conceptual Framework", level=2)
    para(doc, "The conceptual framework follows an input-process-output model. The inputs are user-provided financial records such as income, expenses, budget limits, grocery items, item prices, and bill details. The process includes local storage, budget computation, categorization, analytics generation, bill monitoring, and BAI rule-based analysis. The outputs are budget summaries, spending charts, grocery totals, bill reminders, BAI responses, and user satisfaction results.")
    add_matrix(
        doc,
        ["Input", "Process", "Output"],
        [
            ["Income, expenses, budgets, bills, grocery items, prices", "Local storage, computation, categorization, analytics, and BAI rule-based analysis", "Budget status, spending summaries, reminders, grocery totals, and assistant responses"],
            ["Respondent feedback", "Tabulation and weighted mean analysis", "Acceptability and software quality evaluation results"],
        ],
        [2.05, 2.25, 2.2],
    )

    doc.add_heading("Statement of the Problem", level=2)
    para(doc, "This study aims to design, develop, and evaluate GABAY APP, an offline-first mobile financial management application with a rule-based AI assistant for Filipino users in Butuan City. Specifically, it seeks to answer the following questions:")
    for item in [
        "What are the financial tracking and budgeting needs of the target users that should be addressed by the system?",
        "What features can be developed in GABAY APP to support income and expense tracking, budget monitoring, grocery list management, bill tracking, analytics, and BAI assistance?",
        "How can an offline-first mobile architecture be implemented to store and process user financial records locally?",
        "How acceptable is GABAY APP when evaluated by users in terms of functional suitability, usability, reliability, performance efficiency, and overall satisfaction?",
    ]:
        number(doc, item)

    doc.add_heading("Objectives of the Study", level=2)
    para(doc, "The general objective of the study is to design and develop GABAY APP, an offline-first mobile financial management application with a rule-based AI assistant that helps Filipino users in Butuan City track expenses, manage budgets, monitor bills, organize grocery spending, and improve awareness of their financial habits.")
    para(doc, "Specifically, the study aims:")
    for item in [
        "To design a mobile application that allows users to record income, expenses, bills, grocery items, prices, and budget allocations.",
        "To develop an offline-first financial tracking system using Flutter and local device storage.",
        "To implement BAI, a rule-based assistant that provides budget alerts, spending summaries, bill reminders, and grocery-related suggestions.",
        "To provide analytics that help users understand spending patterns and remaining budget.",
        "To evaluate the system using selected ISO/IEC 25010 software quality criteria and user satisfaction indicators.",
    ]:
        number(doc, item)

    doc.add_heading("Significance of the Study", level=2)
    para(doc, "Filipino users and households. The study may benefit Filipino users who need a simple way to monitor daily expenses, bills, grocery spending, and budget limits. GABAY can reduce reliance on handwritten notes and help users become more aware of where their money is spent.")
    para(doc, "Students and young professionals. The system can help users who are beginning to manage allowances, salaries, or personal expenses by giving them a structured tool for recording and reviewing financial activity.")
    para(doc, "Information technology students and developers. The study demonstrates how Flutter, local storage, analytics, and a rule-based assistant can be integrated into a mobile financial management application.")
    para(doc, "Academic institutions and future researchers. The study may serve as a reference for future system-based capstone projects related to financial technology, offline-first mobile applications, and AI-assisted user support.")

    doc.add_heading("Scope and Limitations of the Study", level=2)
    para(doc, "The study covers the design, development, and evaluation of GABAY APP as a mobile application for Filipino users in Butuan City aged 18 years old and above. The system includes manual income and expense tracking, budget allocation, grocery list management, price history, bill tracking, analytics, and BAI rule-based assistance. The core features are designed to work offline using local device storage.")
    para(doc, "The study is limited to financial tracking and budgeting support. GABAY does not connect to banks, e-wallets, or payment gateways. It does not process real money, provide professional investment advice, approve loans, or replace consultation with a financial professional. Receipt scanning, automatic SMS reading, cloud synchronization, predictive spending, and external AI chatbot integration are considered possible future enhancements and are not part of the required final scope of this study.")

    doc.add_heading("Definition of Terms", level=2)
    for term, definition in [
        ("GABAY APP", "Guided Asset Budgeting AI for You; the mobile financial management application developed in this study."),
        ("BAI or Brother AI", "The rule-based assistant in GABAY that provides budgeting support, reminders, summaries, and simple responses based on user-entered data."),
        ("Offline-first", "A design approach where the core features of the application continue to work without continuous internet connection."),
        ("Budget allocation", "The amount of money assigned by the user for a specific period or spending activity."),
        ("Bill tracking", "The recording and monitoring of due dates, amounts, and payment status for recurring or future obligations."),
        ("Grocery list management", "The creation and monitoring of grocery items, quantities, prices, and shopping budgets."),
        ("Price history", "Stored records of item prices from previous grocery entries or stores."),
        ("Rule-based assistant", "A system that generates responses using predefined conditions instead of machine learning prediction or cloud-based generative AI."),
        ("SharedPreferences", "A Flutter-supported local storage mechanism used by the application to save user records on the device."),
    ]:
        para(doc, definition, bold_label=f"{term}. ")

    doc.add_page_break()
    doc.add_heading("Chapter 2", level=1)
    centered(doc, "METHODOLOGY", 12, True)

    doc.add_heading("Research Design", level=2)
    para(doc, "This study uses developmental research design because its main output is the design, development, and evaluation of a mobile application. Developmental research is appropriate for studies that produce an instructional, technological, or software product and evaluate the product based on defined criteria. The study also uses a descriptive evaluation approach to determine the acceptability of GABAY APP based on user feedback.")
    para(doc, "The development process follows the Agile Software Development Life Cycle. Agile is suitable for this study because the application requires iterative design, coding, testing, and refinement. Features such as grocery management, bill tracking, analytics, and BAI responses can be developed and improved through repeated cycles of feedback and revision.")

    doc.add_heading("Research Environment", level=2)
    para(doc, "The study will be conducted in Butuan City. The selected environment is appropriate because the study focuses on Filipino users who manage personal or household expenses and can provide feedback on the usefulness and usability of a mobile budgeting application.")

    doc.add_heading("Population and Sample", level=2)
    para(doc, "The target respondents are Filipino residents of Butuan City who are 18 years old and above, use a smartphone, and manage personal or household expenses. Respondents may include students, employees, self-employed individuals, and other users who perform budgeting or expense tracking activities. The final number of respondents will follow the requirement of the institution and adviser.")

    doc.add_heading("Sampling Technique", level=2)
    para(doc, "The study will use purposive sampling. Respondents will be selected based on their relevance to the study, particularly their experience in managing expenses and their ability to use and evaluate a mobile application. This technique is appropriate because the evaluation requires participants who can test the system and provide meaningful feedback.")

    doc.add_heading("System Development Method", level=2)
    add_matrix(
        doc,
        ["Agile Phase", "Activities in the Study"],
        [
            ["Planning", "Identify user needs, system scope, target users, and required modules."],
            ["Design", "Prepare interface flow, data structure, feature design, and BAI rule logic."],
            ["Development", "Implement Flutter screens, local storage services, analytics, bill tracking, grocery management, and BAI responses."],
            ["Testing", "Check computations, navigation, local data persistence, budget warnings, and assistant responses."],
            ["Evaluation", "Allow respondents to use the application and answer the evaluation questionnaire."],
            ["Revision", "Improve the system and manuscript based on testing results and adviser feedback."],
        ],
        [1.7, 4.8],
    )

    doc.add_heading("System Architecture", level=2)
    para(doc, "GABAY follows a layered mobile application architecture. The presentation layer contains the Flutter screens and widgets used by the user. The state and service layer handles application logic such as budgets, grocery records, bills, finance records, price history, and settings. The persistence layer stores data locally using SharedPreferences. The BAI module receives context from stored records and generates rule-based responses.")
    add_matrix(
        doc,
        ["Layer", "Components", "Responsibility"],
        [
            ["Presentation Layer", "Flutter pages and widgets", "Displays screens for dashboard, wallet, grocery, bills, analytics, settings, and BAI chat."],
            ["Service Layer", "GroceryStorage, BillStorage, FinanceStorage, PriceStorage, SettingsService", "Saves, loads, updates, and computes user records."],
            ["Persistence Layer", "SharedPreferences", "Stores records locally on the user's device."],
            ["BAI Module", "BAI assistant and rule logic", "Analyzes user records and generates budgeting support, reminders, and summaries."],
            ["Output Layer", "Charts, summaries, reminders, assistant replies", "Shows financial feedback and system results to the user."],
        ],
        [1.4, 2.3, 2.8],
    )

    doc.add_heading("Research Instrument", level=2)
    para(doc, "The primary research instrument is a researcher-made questionnaire based on selected ISO/IEC 25010 software quality criteria. The questionnaire will use a four-point Likert scale: 4 - Strongly Agree, 3 - Agree, 2 - Disagree, and 1 - Strongly Disagree. The instrument will evaluate functional suitability, usability, reliability, performance efficiency, and overall satisfaction.")
    add_matrix(
        doc,
        ["Criterion", "Focus of Evaluation"],
        [
            ["Functional suitability", "Correctness and usefulness of expense tracking, budgeting, grocery, bills, analytics, and BAI features."],
            ["Usability", "Ease of navigation, clarity of interface, learnability, and user friendliness."],
            ["Reliability", "Consistency of local data storage, app stability, and offline functionality."],
            ["Performance efficiency", "Responsiveness of screens, computations, and assistant replies on a mobile device."],
            ["Overall satisfaction", "General user acceptance of GABAY as a financial management tool."],
        ],
        [2.0, 4.5],
    )

    doc.add_heading("Data Gathering Procedure", level=2)
    for item in [
        "The researchers will finalize the system scope, features, and evaluation instrument with adviser approval.",
        "The researchers will develop and test the GABAY mobile application.",
        "Qualified respondents will be invited to participate voluntarily.",
        "Respondents will be oriented about the purpose of the study, the voluntary nature of participation, and the privacy of their responses.",
        "Respondents will be allowed to use or observe the working application.",
        "Respondents will answer the evaluation questionnaire.",
        "The researchers will tabulate, analyze, and interpret the results using the selected statistical treatment.",
    ]:
        number(doc, item)

    doc.add_heading("Ethical Considerations", level=2)
    para(doc, "Participation in the study will be voluntary. Respondents will be informed about the purpose of the study and their right to withdraw at any time. The researchers will not collect bank credentials, e-wallet credentials, or real payment access. The application will not perform actual financial transactions. Any information collected through the questionnaire will be used only for academic purposes and will be treated with confidentiality.")

    doc.add_heading("Statistical Treatment", level=2)
    para(doc, "The study will use weighted mean to interpret respondent ratings for each evaluation criterion. The formula is:")
    centered(doc, "Weighted Mean = Sum(fx) / N", 12, True)
    para(doc, "where f is the frequency of responses, x is the assigned Likert scale value, and N is the total number of responses. The following interpretation scale will be used:")
    add_matrix(
        doc,
        ["Range", "Verbal Interpretation"],
        [
            ["3.26 - 4.00", "Strongly Agree / Highly Acceptable"],
            ["2.51 - 3.25", "Agree / Acceptable"],
            ["1.76 - 2.50", "Disagree / Less Acceptable"],
            ["1.00 - 1.75", "Strongly Disagree / Not Acceptable"],
        ],
        [2.0, 4.5],
    )

    doc.add_heading("Data Analysis Procedure", level=2)
    para(doc, "After collecting the questionnaire responses, the researchers will tabulate the results according to the selected software quality criteria. The weighted mean for each criterion will be computed and interpreted using the scale provided. The findings will determine the level of acceptability of GABAY APP and identify areas that may require improvement.")

    doc.add_heading("Proposed Evaluation Questionnaire", level=2)
    add_matrix(
        doc,
        ["Criterion", "Sample Indicator"],
        [
            ["Functional suitability", "The app allows me to record and monitor income, expenses, budgets, bills, and grocery items correctly."],
            ["Functional suitability", "BAI provides useful budget alerts, summaries, and reminders based on my records."],
            ["Usability", "The app is easy to navigate and understand."],
            ["Usability", "The interface is clear for users who are not highly technical."],
            ["Reliability", "The app keeps my records available even without internet connection."],
            ["Reliability", "The app performs consistently during normal use."],
            ["Performance efficiency", "The app responds quickly when adding records, viewing analytics, or asking BAI."],
            ["Overall satisfaction", "Overall, I am satisfied with GABAY as a financial management tool."],
        ],
        [2.0, 4.5],
    )

    doc.add_page_break()
    doc.add_heading("References", level=1)
    refs = [
        "Ajzen, I. (1991). The theory of planned behavior. Organizational Behavior and Human Decision Processes, 50(2), 179-211. https://doi.org/10.1016/0749-5978(91)90020-T",
        "Beck, K., Beedle, M., van Bennekum, A., Cockburn, A., Cunningham, W., Fowler, M., Grenning, J., Highsmith, J., Hunt, A., Jeffries, R., Kern, J., Marick, B., Martin, R. C., Mellor, S., Schwaber, K., Sutherland, J., & Thomas, D. (2001). Manifesto for agile software development. Agile Alliance. https://agilemanifesto.org/",
        "Creswell, J. W. (2014). Research design: Qualitative, quantitative, and mixed methods approaches (4th ed.). SAGE Publications.",
        "Davis, F. D. (1989). Perceived usefulness, perceived ease of use, and user acceptance of information technology. MIS Quarterly, 13(3), 319-340. https://doi.org/10.2307/249008",
        "Ellis, T. J., & Levy, Y. (2010). A guide for novice researchers: Design and development research methods. Proceedings of Informing Science & IT Education Conference, 107-118. https://doi.org/10.28945/1237",
        "Hilgert, M. A., Hogarth, J. M., & Beverly, S. G. (2003). Household financial management: The connection between knowledge and behavior. Federal Reserve Bulletin, 89, 309-322. https://www.federalreserve.gov/pubs/bulletin/2003/0703lead.pdf",
        "Huang, J., & Yang, Z. (2019). Write or type? How a paper versus digital shopping list influences the way consumers plan and shop. Journal of the Association for Consumer Research, 4(3), 265-277. https://doi.org/10.1086/704313",
        "International Organization for Standardization. (2011). ISO/IEC 25010:2011 systems and software engineering - Systems and software quality requirements and evaluation (SQuaRE) - System and software quality models. https://www.iso.org/standard/35733.html",
        "Kleppmann, M., Wiggins, A., van Hardenberg, P., & McGranaghan, M. (2019). Local-first software: You own your data, in spite of the cloud. Proceedings of the ACM SIGPLAN International Symposium on New Ideas, New Paradigms, and Reflections on Programming and Software, 154-178. https://doi.org/10.1145/3359591.3359737",
        "Philippine Statistics Authority. (2022). 2021 Family Income and Expenditure Survey. https://psa.gov.ph/content/2021-family-income-and-expenditure-survey",
        "Shneiderman, B. (2020). Human-centered artificial intelligence: Reliable, safe and trustworthy. International Journal of Human-Computer Interaction, 36(6), 495-504. https://doi.org/10.1080/10447318.2020.1741118",
    ]
    for ref in refs:
        p = doc.add_paragraph(ref)
        p.paragraph_format.first_line_indent = Inches(-0.5)
        p.paragraph_format.left_indent = Inches(0.5)
        p.paragraph_format.space_after = Pt(6)

    doc.add_page_break()
    doc.add_heading("Adviser Revision Notes", level=1)
    para(doc, "This finalized draft intentionally narrows the study to a defensible system scope. It treats BAI as a rule-based assistant rather than a cloud chatbot or predictive AI model. It also excludes bank integration, real-money transactions, investment advice, receipt scanning, SMS scanning, and predictive spending from the required final scope. These may be discussed only as future enhancements unless implemented and tested.")
    para(doc, "Before submission, the group should confirm the required school format, final respondent count, and whether the adviser wants Chapter 1 and the review of related literature separated into different chapters. The questionnaire should also be validated by the adviser or qualified evaluators before respondent testing.")

    doc.save(OUT)
    print(OUT)


if __name__ == "__main__":
    build()
